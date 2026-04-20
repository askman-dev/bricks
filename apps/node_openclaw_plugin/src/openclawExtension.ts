import {
  BRICKS_CHANNEL_CONFIG_SCHEMA,
  bricksChannelPlugin,
} from './bricksChannelPlugin.js';
import { CHANNEL_DESCRIPTION, CHANNEL_ID, CHANNEL_NAME } from './channelConstants.js';

interface ChannelRegistrationApi {
  registrationMode?: string;
  registerChannel(params: { plugin: typeof bricksChannelPlugin }): void;
}

const pluginEntry = {
  id: CHANNEL_ID,
  name: CHANNEL_NAME,
  description: CHANNEL_DESCRIPTION,
  configSchema: BRICKS_CHANNEL_CONFIG_SCHEMA,
  register(api: ChannelRegistrationApi) {
    if (api.registrationMode === 'cli-metadata') {
      return;
    }

    api.registerChannel({ plugin: bricksChannelPlugin });
  },
  channelPlugin: bricksChannelPlugin,
};

export default pluginEntry;
export { BRICKS_CHANNEL_CONFIG_SCHEMA, bricksChannelPlugin } from './bricksChannelPlugin.js';
export { CHANNEL_ID, DEFAULT_ACCOUNT_ID } from './channelConstants.js';
