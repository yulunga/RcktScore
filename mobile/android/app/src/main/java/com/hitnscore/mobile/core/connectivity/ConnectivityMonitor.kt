package com.hitnscore.mobile.core.connectivity

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Whether the phone currently has a validated internet connection, as iOS `NetworkMonitor`. */
interface ConnectivityMonitor {
    val isOnline: StateFlow<Boolean>
}

class AndroidConnectivityMonitor(context: Context) : ConnectivityMonitor {
    private val connectivityManager = context.getSystemService(ConnectivityManager::class.java)
    private val validatedNetworks = mutableSetOf<Network>()
    private val mutableOnline = MutableStateFlow(currentlyOnline())
    override val isOnline: StateFlow<Boolean> = mutableOnline.asStateFlow()

    init {
        connectivityManager.registerDefaultNetworkCallback(
            object : ConnectivityManager.NetworkCallback() {
                override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
                    synchronized(validatedNetworks) {
                        if (capabilities.hasInternet()) validatedNetworks += network else validatedNetworks -= network
                        mutableOnline.value = validatedNetworks.isNotEmpty()
                    }
                }

                override fun onLost(network: Network) {
                    synchronized(validatedNetworks) {
                        validatedNetworks -= network
                        mutableOnline.value = validatedNetworks.isNotEmpty()
                    }
                }
            },
        )
    }

    private fun currentlyOnline(): Boolean =
        connectivityManager.getNetworkCapabilities(connectivityManager.activeNetwork)?.hasInternet() == true

    private fun NetworkCapabilities.hasInternet() =
        hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
}
