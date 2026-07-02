import { loadConfig } from './config.js';
import { createServer } from './server.js';

const config = loadConfig();
const server = createServer(config);

server.listen(config.port, config.host, () => {
  console.log(
    `[bricks-sandbox-runner] listening on ${config.host}:${config.port} ` +
      `root=${config.sandboxRoot} runtime=${config.runtime}`,
  );
});
