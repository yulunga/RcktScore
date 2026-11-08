package com.hitnscore.mobile.core.profile

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

@OptIn(ExperimentalCoroutinesApi::class)
class ProfilePhotoStoreTest {
    @get:Rule
    val folder = TemporaryFolder()

    private fun store() = ProfilePhotoStore(folder.root.resolve("profile_photos"), UnconfinedTestDispatcher())

    @Test
    fun noPhotoUntilOneIsSaved() = runTest {
        assertNull(store().read("pat@example.com"))
    }

    @Test
    fun savedPhotoIsReadBackForTheSameUserOnly() = runTest {
        val store = store()
        val jpeg = byteArrayOf(1, 2, 3)
        store.save("Pat@Example.com ", jpeg)
        assertArrayEquals(jpeg, store.read("pat@example.com"))
        assertNull(store.read("sam@example.com"))
    }

    @Test
    fun fileNameDoesNotRevealTheEmail() {
        val name = store().fileFor("pat@example.com").name
        assertFalse("pat" in name)
        assertEquals(64 + ".jpg".length, name.length)
    }

    @Test
    fun replacingAndRemovingBumpTheVersion() = runTest {
        val store = store()
        store.save("pat@example.com", byteArrayOf(1))
        store.save("pat@example.com", byteArrayOf(2))
        assertEquals(2, store.versionOf("pat@example.com"))
        assertArrayEquals(byteArrayOf(2), store.read("pat@example.com"))
        store.remove("pat@example.com")
        assertNull(store.read("pat@example.com"))
        assertEquals(3, store.versionOf("pat@example.com"))
        assertEquals(0, store.versionOf("sam@example.com"))
    }
}
