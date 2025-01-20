import Foundation

// Just a list of OctoPrint plugins that are supported by OctoPod
// The constants are used for identifying plugins
struct Plugins {

    static let CUSTOM_CONTROL = "custom_control "
    static let MULTICAM = "multicam"
    static let PSU_CONTROL = "psucontrol"
    static let TP_LINK_SMARTPLUG = "tplinksmartplug"    // Considered an IP Plug plugin
    static let WEMO_SWITCH = "wemoswitch"               // Considered an IP Plug plugin
    static let DOMOTICZ = "domoticz"                    // Considered an IP Plug plugin
    static let TASMOTA = "tasmota"                      // Considered an IP Plug plugin
    static let CANCEL_OBJECT = "cancelobject"
    static let OCTOPOD = "octopod"
    static let PALETTE_2 = "palette2"
    static let PALETTE_2_CANVAS = "canvas"
    static let DISPLAY_LAYER_PROGRESS = "DisplayLayerProgress-websocket-payload"
    static let ENCLOSURE = "enclosure"
    static let FILAMENT_MANAGER = "filamentmanager"
    static let SPOOL_MANAGER = "SpoolManager"
    static let BL_TOUCH = "BLTouch"
    static let OCTO_RELAY = "octorelay"
    static let OCTO_LIGHT_HA = "octolightHA"
    static let PRINT_TIME_GENIUS = "PrintTimeGenius"
}
