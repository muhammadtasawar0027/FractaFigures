import UIKit

final class OrientationManager {
    static let shared = OrientationManager()
    
    private init() {}
    
    func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.orientationLock = orientation
    }
    
    func lockToPortrait() {
        lockOrientation(.portrait)
        rotateToPortrait()
    }
    
    func unlockAllOrientations() {
        lockOrientation(.all)
    }
    
    private func rotateToPortrait() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        
        let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
        windowScene.requestGeometryUpdate(geometryPreferences) { _ in }
        
        for window in windowScene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}
