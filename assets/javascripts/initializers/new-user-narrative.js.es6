import { withPluginApi } from 'discourse/lib/plugin-api';
import HeaderWidget from 'discourse/widgets/header';

function initialize(api) {
  const messageBus = api.container.lookup('message-bus:main');
  const currentUser = api.getCurrentUser();
  const appEvents = api.container.lookup('app-events:main');
  const SiteHeaderComponent = api.container.lookupFactory('component:site-header');

  SiteHeaderComponent.reopen({
    didInsertElement() {
      this._super();
      this.dispatch('header:search-context-trigger', 'header');
    }
  });

  api.attachWidgetAction('header', 'headerSearchContextTrigger', function() {
    this.state.contextEnabled = true;
  });

  if (messageBus && currentUser) {
    messageBus.subscribe(`/new_user_narrative/tutorial_search`, () => {
      appEvents.trigger('header:search-context-trigger');
    });
  }
}

export default {
  name: "new-user-narratve",

  initialize(container) {
    const siteSettings = container.lookup('site-settings:main');
    if (siteSettings.introbot_enabled) withPluginApi('0.5', initialize);
  }
};
