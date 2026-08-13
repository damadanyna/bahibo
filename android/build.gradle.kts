allprojects {
    repositories {
        maven {
            url = uri(rootProject.file("../.flutter-offline-repo-v2/download.flutter.io"))
        }
        google()
        mavenCentral()
    }
}

subprojects {
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:-options")
    }
    // receive_sharing_intent's own module doesn't pin a JVM target and picks
    // up a Kotlin default that drifts from its Java target, failing the
    // build with "Inconsistent JVM Target Compatibility". Fix scoped to just
    // this one module so it can't affect any other (already working) plugin.
    if (project.name == "receive_sharing_intent") {
        // The plugin doesn't declare compileOptions at all, so AGP falls
        // back to its legacy Java 1.8 default — mismatching the Kotlin side
        // below. Set it through the android{} extension itself (the same
        // mechanism AGP uses internally), deferred to afterEvaluate so it
        // runs after this subproject's own script has fully configured its
        // android{} block.
        project.afterEvaluate {
            extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
                ?.compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
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
