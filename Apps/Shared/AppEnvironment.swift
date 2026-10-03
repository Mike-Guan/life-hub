/// Which build this is. Set per Xcode configuration in project.yml.
enum AppEnvironment {
    // Shown so a test build can't be mistaken for the real one.
    /// Header badge text on non-PROD builds.
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
