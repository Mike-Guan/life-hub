/// Which build this is. Set per Xcode configuration in project.yml.
enum AppEnvironment {
    /// Shown in the header on non-PROD builds so they can't be mistaken for the real one.
    static var badge: String? {
        #if ENV_DEV
        "DEV"
        #elseif ENV_STG
        "STG"
        #else
        nil
        #endif
    }
}
