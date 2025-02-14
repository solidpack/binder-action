#!/bin/bash
set -e

GRADLE_TASK=$1
PLUGIN_VERSION=$2
DEPTH=$3
PACKAGE=$4
CLASSNAME=$5
ARTIFACT_ID=$6
ARTIFACT_VERSION=$7
SHOULD_PUBLISH=$8
REPO_URL=$9
REPO_USER=${10}
REPO_PASSWORD=${11}
shift 11 # Remove first 10 args, remaining are namespaces
NAMESPACES=("$@")

echo "Setting up Gradle..."
mkdir -p gradle_project
cd gradle_project

# Download Gradle if not already present
if [ ! -d "gradle_home" ]; then
    curl -sS https://services.gradle.org/distributions/gradle-8.10-bin.zip -o gradle.zip
    unzip -q gradle.zip
    rm gradle.zip
    mv gradle-* gradle_home
    ln -s gradle_home/bin/gradle gradlew
    chmod +x gradlew
fi

# Initialize Gradle Project
./gradlew init --type basic --dsl kotlin || echo "Gradle project already initialized"

# Generate the Gradle Kotlin build script
echo "Generating build.gradle.kts..."
cat <<EOF > build.gradle.kts
plugins {
    id("io.github.solid-resourcepack.binder") version "$PLUGIN_VERSION"
    id("org.jetbrains.kotlin.jvm") version "1.9.24"
    id("maven-publish")
}

sourceSets.main {
    kotlin.srcDir("build/generated")
}

dependencies {
    api("io.github.solid-resourcepack.binder:api:$PLUGIN_VERSION")
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.9.24")
}

java {
    toolchain.languageVersion.set(JavaLanguageVersion.of(21))
}

kotlin {
    jvmToolchain(21)
    compilerOptions {
        apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_9)
        jvmTarget.set(JvmTarget.JVM_21)
    }
}

packBinder {
    packPath.from(layout.projectDirectory.dir("pack")) // Define paths where your resource packs are
    nameDepth = $DEPTH // How much depth of the model namespace should be included
$(for ns in "${NAMESPACES[@]}"; do echo "    namespaces.add(\"$ns\")"; done)
    dest.set(layout.buildDirectory.dir("generated")) // Set the destination dir
    packageName.set("$PACKAGE") // Set the package of the generated classes
    className.set("$CLASSNAME") // Set the class name of the resulting enum
}

// Publishing Configuration
publishing {
    repositories {
        maven {
            name = "Reposilite"
            url = uri("$REPO_URL")
            credentials {
                username = "$REPO_USER"
                password = "$REPO_PASSWORD"
            }
        }
    }
    publications {
        create<MavenPublication>("maven") {
            from(components["java"])
            groupId = "$PACKAGE"
            artifactId = "$ARTIFACT_ID"
            version = "$ARTIFACT_VERSION"
        }
    }
}
EOF

echo "Running Gradle task: $GRADLE_TASK"
./gradlew "$GRADLE_TASK" --project-dir $""GITHUB_WORKSPACE""

if [ "$SHOULD_PUBLISH" == "true" ]; then
    echo "Publishing to Reposilite..."
    ./gradlew publish --project-dir $""GITHUB_WORKSPACE""
fi
