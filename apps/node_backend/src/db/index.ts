import pg from 'pg';
import { createClient as createLibsqlClient } from '@libsql/client';
import dotenv from 'dotenv';

dotenv.config();

const { Pool } = pg;

type QueryResult<T = any> = {
  rows: T[];
  rowCount: number;
};

export type DatabaseDialect = 'postgres' | 'turso';

type QueryableClient = {
  query: <T = any>(text: string, params?: unknown[]) => Promise<QueryResult<T>>;
  release: () => void;
};

type QueryablePool = {
  dialect: DatabaseDialect;
  query: <T = any>(text: string, params?: unknown[]) => Promise<QueryResult<T>>;
  connect: () => Promise<QueryableClient>;
  end: () => Promise<void>;
};

function resolvePostgresUrl(): string {
  const candidateEnvVars = [
    'DATABASE_URL',
    'POSTGRES_URL',
    'POSTGRES_PRISMA_URL',
    'POSTGRES_URL_NON_POOLING',
  ] as const;

  for (const envVar of candidateEnvVars) {
    const value = process.env[envVar];
    if (value && value.trim().length > 0) {
      return value;
    }
  }

  throw new Error(
    `Database configuration missing. Set one of: ${candidateEnvVars.join(', ')}.`
  );
}

function convertPgPlaceholdersToSqlite(text: string): string {
  // Preserve parameter indices: map PostgreSQL-style $1, $2, ... to SQLite-style ?1, ?2, ...
  return text.replace(/\$(\d+)/g, '?$1');
}

function createTursoPool(): QueryablePool {
  const tursoUrl = process.env.TURSO_DATABASE_URL;
  const tursoAuthToken = process.env.TURSO_AUTH_TOKEN;

  if (!tursoUrl) {
    throw new Error('Turso configuration missing. Set TURSO_DATABASE_URL.');
  }

  const tursoClient = createLibsqlClient({
    url: tursoUrl,
    authToken: tursoAuthToken,
  });

  const executeWithClient = async <T = any>(
    client: typeof tursoClient,
    text: string,
    params: unknown[] = []
  ): Promise<QueryResult<T>> => {
    const statement = convertPgPlaceholdersToSqlite(text);
    const result = await client.execute({
      sql: statement,
      args: params as any[],
    });

    return {
      rows: result.rows as T[],
      rowCount: result.rowsAffected,
    };
  };

  const query = async <T = any>(text: string, params: unknown[] = []): Promise<QueryResult<T>> => {
    return executeWithClient<T>(tursoClient, text, params);
  };

  return {
    dialect: 'turso',
    query,
    connect: async () => {
      let activeTx: Awaited<ReturnType<typeof tursoClient.transaction>> | null = null;

      return {
        query: async <T = any>(text: string, params: unknown[] = []): Promise<QueryResult<T>> => {
          const cmd = text.trim().toUpperCase();

          if (cmd === 'BEGIN') {
            activeTx = await tursoClient.transaction('write');
            return { rows: [], rowCount: 0 };
          }

          if (cmd === 'COMMIT') {
            if (activeTx) {
              await activeTx.commit();
              activeTx = null;
            }
            return { rows: [], rowCount: 0 };
          }

          if (cmd === 'ROLLBACK') {
            if (activeTx) {
              try {
                await activeTx.rollback();
              } catch (err) {
                // Transaction may already be closed by a prior error; log and continue
                console.warn('Turso transaction rollback skipped:', (err as Error).message);
              }
              activeTx = null;
            }
            return { rows: [], rowCount: 0 };
          }

          if (activeTx) {
            const statement = convertPgPlaceholdersToSqlite(text);
            const result = await activeTx.execute({
              sql: statement,
              args: params as any[],
            });
            return {
              rows: result.rows as T[],
              rowCount: result.rowsAffected,
            };
          }

          return executeWithClient<T>(tursoClient, text, params);
        },
        release: () => {
          if (activeTx) {
            activeTx.close();
            activeTx = null;
          }
        },
      };
    },
    end: async () => {},
  };
}

function createPostgresPool(): QueryablePool {
  const databaseUrl = resolvePostgresUrl();
  const pgPool = new Pool({
    connectionString: databaseUrl,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
  });

  return {
    dialect: 'postgres',
    query: async <T = any>(text: string, params: unknown[] = []): Promise<QueryResult<T>> => {
      const result = await pgPool.query(text, params);
      return {
        rows: result.rows as T[],
        rowCount: result.rowCount ?? 0,
      };
    },
    connect: async () => {
      const client = await pgPool.connect();
      return {
        query: async <T = any>(text: string, params: unknown[] = []): Promise<QueryResult<T>> => {
          const result = await client.query(text, params);
          return {
            rows: result.rows as T[],
            rowCount: result.rowCount ?? 0,
          };
        },
        release: () => client.release(),
      };
    },
    end: async () => {
      await pgPool.end();
    },
  };
}

// Database connection pool
export const pool: QueryablePool = process.env.TURSO_DATABASE_URL
  ? createTursoPool()
  : createPostgresPool();

// Test database connection
export async function testConnection(): Promise<boolean> {
  let client: QueryableClient | undefined;
  try {
    client = await pool.connect();
    await client.query('SELECT 1');
    console.log('Database connection successful');
    return true;
  } catch (error) {
    console.error('Database connection failed:', error);
    return false;
  } finally {
    client?.release();
  }
}

// Close pool (for graceful shutdown)
export async function closePool(): Promise<void> {
  await pool.end();
}

export default pool;
