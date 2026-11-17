import Foundation

func L(_ key: String, _ table: String = "Localizable") -> String {
    return NSLocalizedString(key, tableName: table, bundle: Bundle.main, value: key, comment: "")
}
