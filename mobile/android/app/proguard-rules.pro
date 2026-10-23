# kotlinx.serialization ships its own R8 rules. Keep our API models' generated
# serializers explicitly as a belt-and-braces measure for the release build.
-keepclassmembers @kotlinx.serialization.Serializable class com.hitnscore.mobile.** {
    *** Companion;
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.hitnscore.mobile.**$$serializer { *; }

# Keep line numbers for readable crash reports; hide original source file names.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
