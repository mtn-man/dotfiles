local function usbDeviceCallback(data)
    if data["productName"] == "USB Receiver" and data["vendorID"] == 1133 then
        if data["eventType"] == "added" then
            hs.application.launchOrFocus("LinearMouse")
        elseif data["eventType"] == "removed" then
            local app = hs.application.find("LinearMouse")
            if app then app:kill() end
        end
    end
end

local usbWatcher = hs.usb.watcher.new(usbDeviceCallback)
usbWatcher:start()

local wifiWatcher = hs.wifi.watcher.new(function()
    if hs.wifi.currentNetwork() == "AOL Dialup" then
        hs.execute("/opt/homebrew/bin/tailscale up", true)
    end
end)
wifiWatcher:start()
