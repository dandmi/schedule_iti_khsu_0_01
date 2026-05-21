allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // home_widget 0.8.x uses dynamic AndroidX Glance dependencies.
    // Without pinning Gradle may resolve androidx.glance:glance-appwidget:1.3.0-alpha01,
    // which requires compileSdk 37 and Android Gradle Plugin 9.1+.
    // The app uses a native RemoteViews widget, so Glance 1.1.1 is sufficient here
    // and keeps the build compatible with the current Android Gradle Plugin.
    configurations.all {
        resolutionStrategy {
            force(
                "androidx.glance:glance:1.1.1",
                "androidx.glance:glance-appwidget:1.1.1",
                "androidx.glance:glance-appwidget-proto:1.1.1"
            )
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
