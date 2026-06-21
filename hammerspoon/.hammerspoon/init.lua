local function usbDeviceCallback(data)
    local isLogitech = data["productName"] == "USB Receiver" and data["vendorID"] == 1133
    local isCompx = data["productName"] == "2.4G Receiver" and data["vendorID"] == 9639
    if isLogitech or isCompx then
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

for _, device in ipairs(hs.usb.attachedDevices()) do
    usbDeviceCallback({ productName = device["productName"], vendorID = device["vendorID"], eventType = "added" })
end
