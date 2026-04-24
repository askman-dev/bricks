import Flutter
import UIKit
import app_links

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
      AppLinks.shared.handleLink(url: context.url)
    }
    super.scene(scene, openURLContexts: URLContexts)
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if let url = userActivity.webpageURL {
      AppLinks.shared.handleLink(url: url)
    }
    super.scene(scene, continue: userActivity)
  }
}
