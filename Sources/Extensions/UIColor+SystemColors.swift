import UIKit

public enum SystemColors {
    public static var label: UIColor {
        return .label
    }
    
    public static var secondaryLabel: UIColor {
        return .secondaryLabel
    }
    
    public static var systemBackground: UIColor {
        /// Пока Pod испольузется только в WorksPad, используем цвета самого WorksPad, уже добавленные при сборке
        /// При переиспользовании добавить ручки для установки цветовой схемы извне
        return UIColor(named: "WPXSystemBackgroundColor") ?? .systemBackground
    }
    
    public static var secondarySystemBackground: UIColor {
        return .secondarySystemBackground
    }
    
    public static var tertiarySystemBackground: UIColor {
        return .tertiarySystemBackground
    }
    
    public static var systemRed: UIColor {
        return .systemRed
    }
    
    public static var systemBlue: UIColor {
        return .systemBlue
    }
    
    public static var systemGray4: UIColor {
        return .systemGray4
    }
    
    public static var systemSeparator: UIColor {
        return .opaqueSeparator
    }
    
}
