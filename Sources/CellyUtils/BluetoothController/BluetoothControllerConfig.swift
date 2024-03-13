import Foundation

public struct BluetoothControllerConfig: Codable {
    var homingConfig: HomingConfig; public struct HomingConfig: Codable {
        var x: Float
        var y: Float
        var z: Float
        var f: Float
    }

    var joystickFeedspeed: Float

    public static func create(model _: MicroscropeModel) -> BluetoothControllerConfig {
        var config = BluetoothControllerConfig(
            homingConfig: .init(
                x: 3.5,
                y: 11,
                z: 0, // cx21=5, cx23=130,
                f: 3000
            ),

            joystickFeedspeed: 20
        )
        var stageHeigh: Float = 0
        config.homingConfig.z = config.homingConfig.z + stageHeigh
        return config
    }
}
