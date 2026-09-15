plugins {
    application
    java
    id("com.diffplug.spotless") version "8.10.0"
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("ch.qos.logback:logback-classic:1.6.3")
    implementation("org.slf4j:slf4j-api:2.0.19")

    implementation("commons-cli:commons-cli:1.11.0")

    implementation("org.usb4java:usb4java:1.3.0")
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(25)
    }
}

application {
    mainClass = "com.ellie.programmer.Main"
}

spotless {
    java {
        palantirJavaFormat()
        trimTrailingWhitespace()
        endWithNewline()
    }
}
