allprojects {
    repositories {
        google()
        mavenCentral()
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

// بعض إضافات الطرف الثالث (مثل pay_android) تحدد إعدادات JVM قديمة/متضاربة
// بين مهام Java وKotlin الخاصة بها، وهو ما يفشّل البناء تحت AGP 9. توحيدها
// هنا لكل الوحدات الفرعية يحل التعارض دون المساس بإعداد وحدة app نفسها.
// لازم داخل afterEvaluate: AGP يكتب إعداد compileOptions الخاص بكل إضافة
// على مهامها أثناء تقييم مشروعها الفرعي، أي بعد هذا الإعداد هنا مباشرة —
// فبقيت قيمة javac القديمة (11) تكسب رغم هذا التوحيد قبل الإصلاح.
subprojects {
    afterEvaluate {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
