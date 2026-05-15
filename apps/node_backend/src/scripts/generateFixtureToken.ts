import jwt from 'jsonwebtoken';
import { createClient } from '@libsql/client';

function fixtureDatabaseUrl(): string {
  const explicit = process.env.FIXTURE_DATABASE_URL?.trim();
  if (explicit) return explicit;
  return `file:${process.cwd()}/.cache/chat-scroll-fixture.db`;
}

async function inferUserId(): Promise<string> {
  const explicit = process.env.FIXTURE_USER_ID?.trim();
  if (explicit) return explicit;

  const client = createClient({ url: fixtureDatabaseUrl() });
  try {
    const result = await client.execute(`
      SELECT user_id
        FROM chat_messages
       GROUP BY user_id
       ORDER BY MAX(COALESCE(write_seq, seq_id)) DESC
       LIMIT 1
    `);
    const userId = result.rows[0]?.user_id;
    if (typeof userId !== 'string' || userId.trim().length === 0) {
      throw new Error('Could not infer FIXTURE_USER_ID from local fixture DB.');
    }
    return userId;
  } finally {
    client.close();
  }
}

async function main(): Promise<void> {
  const userId = await inferUserId();
  const jwtSecret = process.env.JWT_SECRET?.trim() || 'bricks-local-test-secret';
  const token = jwt.sign({ userId }, jwtSecret);
  console.error(`Generated fixture token for user ${userId}`);
  console.log(token);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
