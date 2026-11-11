pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

// Separate from the phone/tablet app (mobile/android): its own project, ID and Play listing.
rootProject.name = "HitNScoreTvScoreboard"
include(":app")
