import {
  BRICKS_CHANNEL_CONFIG_SCHEMA,
  CHANNEL_DESCRIPTION,
  CHANNEL_ID,
  CHANNEL_NAME,
  bricksChannelPlugin,
} from './bricksChannelPlugin.js';

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
export { BRICKS_CHANNEL_CONFIG_SCHEMA, CHANNEL_ID, DEFAULT_ACCOUNT_ID, bricksChannelPlugin } from './bricksChannelPlugin.js';
