//
//  SimpleExperimentData.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 28.02.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

import Foundation

class SimpleExperimentTemplete {
    
    var rate: Double
    
    init(rate: Double) {
        self.rate = rate
    }
    
    func getContainers(sensors: MapSensorType) -> String {
        
        var containers = ""
        
        
        if sensors.contains(.Accelerometer){
            containers += """
                                <container size=\"0\">accX</container>
                                        <container size=\"0\">accY</container>
                                        <container size=\"0\">accZ</container>
                                        <container size=\"0\">acc_time</container>
                                        
                                """
        }
        if sensors.contains(.Attitude){
            containers += """
                                <container size="0">attWIn</container>
                                        <container size="0">attXIn</container>
                                        <container size="0">attYIn</container>
                                        <container size="0">attZIn</container>
                                        <container size="0">attWOff</container>
                                        <container size="0">attXOff</container>
                                        <container size="0">attYOff</container>
                                        <container size="0">attZOff</container>
                                        <container size="0">attW</container>
                                        <container size="0">attX</container>
                                        <container size="0">attY</container>
                                        <container size="0">attZ</container>
                                        <container size="0">attT</container>
                                        <container size="0">direct</container>
                                        <container size="0">yaw</container>
                                        <container size="0">pitch</container>
                                        <container size="0">roll</container>
                                        <container size="1" init="1">attW0</container>
                                        <container size="1" init="0">attX0</container>
                                        <container size="1" init="0">attY0</container>
                                        <container size="1" init="0">attZ0</container>
                                        <container size="1" init="1">attWLast</container>
                                        <container size="1" init="0">attXLast</container>
                                        <container size="1" init="0">attYLast</container>
                                        <container size="1" init="0">attZLast</container>
                                        <container size="1">count</container>
                                        <container size="1">attTMax</container>
                                        
                                """
        }
        if sensors.contains(.Barometer){
            containers += """
                                <container size=\"0\">baroX</container>
                                        <container size=\"0\">baro_time</container>
                                        
                                """
        }
        if sensors.contains(.GPS){
            containers += """
                                <container size=\"0\">gpsLat</container>
                                        <container size=\"0\">gpsLon</container>
                                        <container size=\"0\">gpsZ</container>
                                        <container size=\"0\">gpsV</container>
                                        <container size=\"0\">gpsDir</container>
                                        <container size=\"0\">gps_time</container>
                                        <container size=\"0\">gpsAccuracy</container>
                                        <container size=\"0\">gpsZAccuracy</container>
                                        <container size=\"1\">gpsStatus</container>
                                        <container size=\"1\">gpsSatellites</container>
                                                
                                """
        }
        if sensors.contains(.Gravity){
            containers += """
                                <container size=\"0\">graT</container>
                                        <container size=\"0\">graX</container>
                                        <container size=\"0\">graY</container>
                                        <container size=\"0\">graZ</container>
                                """
        }
        if sensors.contains(.Gyroscope){
            containers += """
                                <container size=\"0\">gyroX</container>
                                        <container size=\"0\">gyroY</container>
                                        <container size=\"0\">gyroZ</container>
                                        <container size=\"0\">gyro_time</container>
                                        
                                """
        }
        if sensors.contains(.LinearAccelerometer){
            containers += """
                                <container size=\"0\">lin_accX</container>
                                        <container size=\"0\">lin_accY</container>
                                        <container size=\"0\">lin_accZ</container>
                                        <container size=\"0\">lin_acc_time</container>
                                        
                                """
        }
        if sensors.contains(.Magnetometer){
            containers += """
                                <container size=\"0\">magX</container>
                                        <container size=\"0\">magY</container>
                                        <container size=\"0\">magZ</container>
                                        <container size=\"0\">mag_time</container>
                                        
                                """
        }
        if sensors.contains(.Proximity){
            containers += """
                                <container size=\"0\">proxX</container>
                                    <container size=\"0\">prox_time</container>
                                        
                                """
        }
        
        return containers
    }
    
    func getInputs(sensors: MapSensorType) -> String {
        var inputs = ""
        
        
        if sensors.contains(.Accelerometer){
            inputs += """
                        <sensor type=\"accelerometer\" rate=\"\(rate)\">
                                    <output component=\"x\">accX</output>
                                    <output component=\"y\">accY</output>
                                    <output component=\"z\">accZ</output>
                                    <output component=\"t\">acc_time</output>
                                </sensor>
                                        
                        """
        }
        
        if sensors.contains(.Attitude){
            inputs += """
                        <sensor type="attitude">
                                    <output component="x">attXIn</output>
                                    <output component="y">attYIn</output>
                                    <output component="z">attZIn</output>
                                    <output component="abs">attWIn</output>
                                    <output component="t">attT</output>
                                </sensor>
                                
                        """
        }
        
        if sensors.contains(.Barometer){
            inputs += """
                            <sensor type=\"pressure\" rate=\"\(rate)\">
                                        <output component=\"x\">baroX</output>
                                        <output component=\"t\">baro_time</output>
                                    </sensor>
                                        
                            """
        }
        if sensors.contains(.GPS){
            inputs += """
                            <location>
                                        <output component=\"lat\">gpsLat</output>
                                        <output component=\"lon\">gpsLon</output>
                                        <output component=\"z\">gpsZ</output>
                                        <output component=\"v\">gpsV</output>
                                        <output component=\"dir\">gpsDir</output>
                                        <output component=\"accuracy\">gpsAccuracy</output>
                                        <output component=\"zAccuracy\">gpsZAccuracy</output>
                                        <output component=\"status\">gpsStatus</output>
                                        <output component=\"satellites\">gpsSatellites</output>
                                        <output component=\"t\">gps_time</output>
                                    </location>
                                        
                            """
        }
        if sensors.contains(.Gravity){
            inputs += """
                        <sensor type=\"gravity\" rate=\"\(rate)\">
                                    <output component=\"x\">graX</output>
                                    <output component=\"y\">graY</output>
                                    <output component=\"z\">graZ</output>
                                    <output component=\"t\">graT</output>
                                </sensor>
                                        
                        """
        }
        if sensors.contains(.Gyroscope){
            inputs += """
                            <sensor type=\"gyroscope\" rate=\"\(rate)\">
                                        <output component=\"x\">gyroX</output>
                                        <output component=\"y\">gyroY</output>
                                        <output component=\"z\">gyroZ</output>
                                        <output component=\"t\">gyro_time</output>
                                    </sensor>
                                        
                            """
        }
        if sensors.contains(.LinearAccelerometer){
            inputs += """
                            <sensor type=\"linear_acceleration\" rate=\"\(rate)\">
                                        <output component=\"x\">lin_accX</output>
                                        <output component=\"y\">lin_accY</output>
                                        <output component=\"z\">lin_accZ</output>
                                        <output component=\"t\">lin_acc_time</output>
                                    </sensor>
                                        
                            """
        }
        if sensors.contains(.Magnetometer){
            inputs += """
                            <sensor type=\"magnetic_field\" rate=\"\(rate)\">
                                        <output component=\"x\">magX</output>
                                        <output component=\"y\">magY</output>
                                        <output component=\"z\">magZ</output>
                                        <output component=\"t\">mag_time</output>
                                    </sensor>
                                        
                            """
        }
        if sensors.contains(.Proximity){
            inputs += """
                            <sensor type=\"proximity\" rate=\"\(rate)\">
                                        <output component=\"x\">proxX</output>
                                        <output component=\"t\">prox_time</output>
                                    </sensor>
                                        
                            """
        }
        
        
        return inputs
        
    }
    
    func getViews(sensors: MapSensorType) -> String {
        var views = ""
        
        if sensors.contains(.Accelerometer){
            views += """
                    <view label=\"Accelerometer\">
                                <graph timeOnX=\"true\" label=\"X\" labelX=\"t (s)\" labelY=\"a (m/s²)\" partialUpdate=\"true\">
                                    <input axis=\"x\">acc_time</input>
                                    <input axis=\"y\">accX</input>
                                </graph>
                                <graph timeOnX=\"true\" label=\"Y\" labelX=\"t (s)\" labelY=\"a (m/s²)\" partialUpdate=\"true\">
                                    <input axis=\"x\">acc_time</input>
                                    <input axis=\"y\">accY</input>
                                </graph>
                                <graph timeOnX=\"true\" label=\"Z\" labelX=\"t (s)\" labelY=\"a (m/s²)\" partialUpdate=\"true\">
                                    <input axis=\"x\">acc_time</input>
                                    <input axis=\"y\">accZ</input>
                                </graph>
                            </view>
                                        
                """
        }
        if sensors.contains(.Attitude){
            views += """
                        <view label="Attitude with Euler's Angle">
                                    <button label="Zero">
                                        <input>attWLast</input>
                                        <output>attW0</output>
                                        <input>attXLast</input>
                                        <output>attX0</output>
                                        <input>attYLast</input>
                                        <output>attY0</output>
                                        <input>attZLast</input>
                                        <output>attZ0</output>
                                    </button>
                                    <graph label="Direct" labelX="t" unitX="s" labelY="⍺" unitY="°" partialUpdate="true">
                                        <input axis="x">attT</input>
                                        <input axis="y">direct</input>
                                    </graph>
                                    <graph label="Yaw" labelX="t" unitX="s" labelY="ψ" unitY="°" partialUpdate="true">
                                        <input axis="x">attT</input>
                                        <input axis="y">yaw</input>
                                    </graph>
                                    <graph label="Pitch" labelX="t" unitX="s" labelY="θ" unitY="°" partialUpdate="true">
                                        <input axis="x">attT</input>
                                        <input axis="y">pitch</input>
                                    </graph>
                                    <graph label="Roll" labelX="t" unitX="s" labelY="φ" unitY="°" partialUpdate="true">
                                        <input axis="x">attT</input>
                                        <input axis="y">roll</input>
                                    </graph>
                                </view>
                                <view label="Quaternions">
                                    <graph label="Quaternion w" labelX="t" unitX="s" labelY="w" partialUpdate="true">
                                        <input axis="x">attT</input>
                                        <input axis="y">attW</input>
                                    </graph>
                                    <graph label="Quaternion x" labelX="t" unitX="s" labelY="x" partialUpdate="true">
                                        <input axis="x">attT</input>
                                        <input axis="y">attX</input>
                                    </graph>
                                    <graph label="Quaternion y" labelX="t" unitX="s" labelY="y" partialUpdate="true">
                                        <input axis="x">attT</input>
                                        <input axis="y">attY</input>
                                    </graph>
                                    <graph label="Quaternion z" labelX="t" unitX="s" labelY="z" partialUpdate="true">
                                        <input axis="x">attT</input>
                                        <input axis="y">attZ</input>
                                    </graph>
                                </view>
                                
                                        
                        """
        }
        if sensors.contains(.Barometer){
            views += """
                            <view label=\"Barometer\">
                                        <graph timeOnX=\"true\" label=\"Pressure\" labelX=\"t (s)\" labelY=\"p (hPa)\" partialUpdate=\"true\">
                                            <input axis=\"x\">baro_time</input>
                                            <input axis=\"y\">baroX</input>
                                        </graph>
                                    </view>
                                        
                            """
        }
        if sensors.contains(.GPS){
            views += """
                            <view label=\"Location\">
                                        <graph label=\"Latitude\" timeOnX=\"true\" labelX=\"t (s)\" labelY=\"Latitude (°)\" partialUpdate=\"true\">
                                            <input axis=\"x\">gps_time</input>
                                            <input axis=\"y\">gpsLat</input>
                                        </graph>
                                        <graph label=\"Longitude\" timeOnX=\"true\" labelX=\"t (s)\" labelY=\"Longitude (°)\" partialUpdate=\"true\">
                                            <input axis=\"x\">gps_time</input>
                                            <input axis=\"y\">gpsLon</input>
                                        </graph>
                                        <graph label=\"Height\" timeOnX=\"true\" labelX=\"t (s)\" labelY=\"z (m)\" partialUpdate=\"true\">
                                            <input axis=\"x\">gps_time</input>
                                            <input axis=\"y\">gpsZ</input>
                                        </graph>
                                        <graph label=\"Velocity\" timeOnX=\"true\" labelX=\"t (s)\" labelY=\"v (m/s)\" partialUpdate=\"true\">
                                            <input axis=\"x\">gps_time</input>
                                            <input axis=\"y\">gpsV</input>
                                        </graph>
                                        <graph label=\"Direction\" timeOnX=\"true\" labelX=\"t (s)\" labelY=\"heading (°)\" partialUpdate=\"true\">
                                            <input axis=\"x\">gps_time</input>
                                            <input axis=\"y\">gpsDir</input>
                                        </graph>
                                        <value label=\"Horizontal Accuracy\" size=\"1\" precision=\"1\" unit=\"m\">
                                            <input>gpsAccuracy</input>
                                        </value>
                                        <value label=\"Vertical Accuracy\" size=\"1\" precision=\"1\" unit=\"m\">
                                            <input>gpsZAccuracy</input>
                                        </value>
                                        <value label=\"Satellites\" size=\"1\" precision=\"0\">
                                            <input>gpsSatellites</input>
                                        </value>
                                        <value label=\"Status\">
                                            <input>gpsStatus</input>
                                            <map max=\"-1\">GPS disabled</map>
                                            <map max=\"0\">Waiting for signal</map>
                                            <map max=\"1\">Active</map>
                                        </value>
                                    </view>
                                        
                            """
        }
        if sensors.contains(.Gravity){
            views += """
                                <view label=\"Gravity\">
                                            <graph timeOnX=\"true\" label=\"X\" labelX=\"t (s)\" labelY=\"a (m/s²)\" partialUpdate=\"true\">
                                                <input axis=\"x\">graT</input>
                                                <input axis=\"y\">graX</input>
                                            </graph>
                                            <graph timeOnX=\"true\" label=\"Y\" labelX=\"t (s)\" labelY=\"a (m/s²)\" partialUpdate=\"true\">
                                                <input axis=\"x\">graT</input>
                                                <input axis=\"y\">graY</input>
                                            </graph>
                                            <graph timeOnX=\"true\" label=\"Z\" labelX=\"t (s)\" labelY=\"a (m/s²)\" partialUpdate=\"true\">
                                                <input axis=\"x\">graT</input>
                                                <input axis=\"y\">graZ</input>
                                            </graph>
                                        </view>
                                        
                                """
        }
        if sensors.contains(.Gyroscope){
            views += """
                            <view label=\"Gyroscope\">
                                        <graph timeOnX=\"true\" label=\"X\" labelX=\"t (s)\" labelY=\"w (rad/s)\" partialUpdate=\"true\">
                                            <input axis=\"x\">gyro_time</input>
                                            <input axis=\"y\">gyroX</input>
                                        </graph>
                                        <graph timeOnX=\"true\" label=\"Y\" labelX=\"t (s)\" labelY=\"w (rad/s)\" partialUpdate=\"true\">
                                            <input axis=\"x\">gyro_time</input>
                                            <input axis=\"y\">gyroY</input>
                                        </graph>
                                        <graph timeOnX=\"true\" label=\"Z\" labelX=\"t (s)\" labelY=\"w (rad/s)\" partialUpdate=\"true\">
                                            <input axis=\"x\">gyro_time</input>
                                            <input axis=\"y\">gyroZ</input>
                                        </graph>
                                    </view>
                                        
                            """
        }
        if sensors.contains(.LinearAccelerometer){
            views += """
                            <view label=\"Linear Accelerometer\">
                                        <graph timeOnX=\"true\" label=\"X\" labelX=\"t (s)\" labelY=\"a (m/s²)\" partialUpdate=\"true\">
                                            <input axis=\"x\">lin_acc_time</input>
                                            <input axis=\"y\">lin_accX</input>
                                        </graph>
                                        <graph timeOnX=\"true\" label=\"Y\" labelX=\"t (s)\" labelY=\"a (m/s²)\" partialUpdate=\"true\">
                                            <input axis=\"x\">lin_acc_time</input>
                                            <input axis=\"y\">lin_accY</input>
                                        </graph>
                                        <graph timeOnX=\"true\" label=\"Z\" labelX=\"t (s)\" labelY=\"a (m/s²)\" partialUpdate=\"true\">
                                            <input axis=\"x\">lin_acc_time</input>
                                            <input axis=\"y\">lin_accZ</input>
                                        </graph>
                                    </view>
                                        
                            """
        }
        if sensors.contains(.Magnetometer){
            views += """
                            <view label=\"Magnetometer\">
                                        <graph timeOnX=\"true\" label=\"X\" labelX=\"t (s)\" labelY=\"B (µT)\" partialUpdate=\"true\">
                                            <input axis=\"x\">mag_time</input>
                                            <input axis=\"y\">magX</input>
                                        </graph>
                                        <graph timeOnX=\"true\" label=\"Y\" labelX=\"t (s)\" labelY=\"B (µT)\" partialUpdate=\"true\">
                                            <input axis=\"x\">mag_time</input>
                                            <input axis=\"y\">magY</input>
                                        </graph>
                                        <graph timeOnX=\"true\" label=\"Z\" labelX=\"t (s)\" labelY=\"B (µT)\" partialUpdate=\"true\">
                                            <input axis=\"x\">mag_time</input>
                                            <input axis=\"y\">magZ</input>
                                        </graph>
                                    </view>
                                    
                            """
        }
        if sensors.contains(.Proximity){
            views += """
                            <view label=\"Proximity\">
                                        <graph timeOnX=\"true\" label=\"Proximity\" labelX=\"t (s)\" labelY=\"Distance (cm)\" partialUpdate=\"true\">
                                            <input axis=\"x\">prox_time</input>
                                            <input axis=\"y\">proxX</input>
                                        </graph>
                                    </view>
                                        
                            """
        }
        
        
        return views
        
    }
    
    func getAnalysis(sensors: MapSensorType) -> String {
        var analysis = ""
        
        if sensors.contains(.Attitude){
            analysis += """
                        <analysis>
                                <!-- Store last raw value, so we can use it for the zero button -->
                                <append>
                                    <input clear="false">attWIn</input>
                                    <output>attWLast</output>
                                </append>
                                <append>
                                    <input clear="false">attXIn</input>
                                    <output>attXLast</output>
                                </append>
                                <append>
                                    <input clear="false">attYIn</input>
                                    <output>attYLast</output>
                                </append>
                                <append>
                                    <input clear="false">attZIn</input>
                                    <output>attZLast</output>
                                </append>

                                <!-- Apply zero offset to new values -->
                                <formula formula="abs([1]*[5_]+[2]*[6_]+[3]*[7_]+[4]*[8_])">
                                    <input clear="false">attW0</input>
                                    <input clear="false">attX0</input>
                                    <input clear="false">attY0</input>
                                    <input clear="false">attZ0</input>
                                    <input clear="false">attWIn</input>
                                    <input clear="false">attXIn</input>
                                    <input clear="false">attYIn</input>
                                    <input clear="false">attZIn</input>
                                    <output clear="true">attWOff</output>
                                </formula>

                                <formula formula="([1]*[6_]-[2]*[5_]-[3]*[8_]+[4]*[7_])*sign([1]*[5_]+[2]*[6_]+[3]*[7_]+[4]*[8_])">
                                    <input clear="false">attW0</input>
                                    <input clear="false">attX0</input>
                                    <input clear="false">attY0</input>
                                    <input clear="false">attZ0</input>
                                    <input clear="false">attWIn</input>
                                    <input clear="false">attXIn</input>
                                    <input clear="false">attYIn</input>
                                    <input clear="false">attZIn</input>
                                    <output clear="true">attXOff</output>
                                </formula>

                                <formula formula="([1]*[7_]+[2]*[8_]-[3]*[5_]-[4]*[6_])*sign([1]*[5_]+[2]*[6_]+[3]*[7_]+[4]*[8_])">
                                    <input clear="false">attW0</input>
                                    <input clear="false">attX0</input>
                                    <input clear="false">attY0</input>
                                    <input clear="false">attZ0</input>
                                    <input clear="false">attWIn</input>
                                    <input clear="false">attXIn</input>
                                    <input clear="false">attYIn</input>
                                    <input clear="false">attZIn</input>
                                    <output clear="true">attYOff</output>
                                </formula>

                                <formula formula="([1]*[8_]-[2]*[7_]+[3]*[6_]-[4]*[5_])*sign([1]*[5_]+[2]*[6_]+[3]*[7_]+[4]*[8_])">
                                    <input clear="false">attW0</input>
                                    <input clear="false">attX0</input>
                                    <input clear="false">attY0</input>
                                    <input clear="false">attZ0</input>
                                    <input clear="true">attWIn</input>
                                    <input clear="true">attXIn</input>
                                    <input clear="true">attYIn</input>
                                    <input clear="true">attZIn</input>
                                    <output clear="true">attZOff</output>
                                </formula>

                                <!-- Calculate angles for new values -->

                                <formula formula="2*acos([1_])*57.295779513">
                                    <input clear="false">attWOff</input>
                                    <input clear="false">attXOff</input>
                                    <input clear="false">attYOff</input>
                                    <input clear="false">attZOff</input>
                                    <output clear="false">direct</output>
                                </formula>

                                <formula formula="atan2(2*([1_]*[2_]+[3_]*[4_]),1-2*([2_]*[2_]+[3_]*[3_]))*57.295779513">
                                    <input clear="false">attWOff</input>
                                    <input clear="false">attXOff</input>
                                    <input clear="false">attYOff</input>
                                    <input clear="false">attZOff</input>
                                    <output clear="false">yaw</output>
                                </formula>

                                <formula formula="asin(2*([1_]*[3_]-[2_]*[4_]))*57.295779513">
                                    <input clear="false">attWOff</input>
                                    <input clear="false">attXOff</input>
                                    <input clear="false">attYOff</input>
                                    <input clear="false">attZOff</input>
                                    <output clear="false">pitch</output>
                                </formula>

                                <formula formula="atan2(2*([1_]*[4_]+[2_]*[3_]),1-2*([3_]*[3_]+[4_]*[4_]))*57.295779513">
                                    <input clear="false">attWOff</input>
                                    <input clear="false">attXOff</input>
                                    <input clear="false">attYOff</input>
                                    <input clear="false">attZOff</input>
                                    <output clear="false">roll</output>
                                </formula>

                                <!-- APpend new values (with offset removed) to results -->

                                <append>
                                    <input clear="true">attWOff</input>
                                    <output clear="false">attW</output>
                                </append>
                                <append>
                                    <input clear="true">attXOff</input>
                                    <output clear="false">attX</output>
                                </append>
                                <append>
                                    <input clear="true">attYOff</input>
                                    <output clear="false">attY</output>
                                </append>
                                <append>
                                    <input clear="true">attZOff</input>
                                    <output clear="false">attZ</output>
                                </append>

                            </analysis>
                                
                        """
        }
        
        return analysis
        
    }
    
    func getExports(sensors: MapSensorType) -> String {
        
        var exports = ""
        
        if sensors.contains(.Accelerometer){
            exports += """
                            <set name=\"Accelerometer\">
                                        <data name=\"Time (s)\">acc_time</data>
                                        <data name=\"X (m/s^2)\">accX</data>
                                        <data name=\"Y (m/s^2)\">accY</data>
                                        <data name=\"Z (m/s^2)\">accZ</data>
                                    </set>
                                        
                            """
        }
        if sensors.contains(.Attitude){
            exports += """
                            <set name="Orientation">
                                        <data name="Time (s)">attT</data>
                                        <data name="w">attW</data>
                                        <data name="x">attX</data>
                                        <data name="y">attY</data>
                                        <data name="z">attZ</data>
                                        <data name="Direct (°)">direct</data>
                                        <data name="Yaw (°)">yaw</data>
                                        <data name="Pitch (°)">pitch</data>
                                        <data name="Roll (°)">roll</data>
                                    </set>
                                    
                            """
        }
        if sensors.contains(.Barometer){
            exports += """
                            <set name=\"Barometer\">
                                        <data name=\"Time (s)\">baro_time</data>
                                        <data name=\"X (hPa)\">baroX</data>
                                    </set>
                                        
                            """
        }
        if sensors.contains(.GPS){
            exports += """
                            <set name=\"Location\">
                                        <data name=\"Time (s)\">gps_time</data>
                                        <data name=\"Latitude (°)\">gpsLat</data>
                                        <data name=\"Longitude (°)\">gpsLon</data>
                                        <data name=\"Height (m)\">gpsZ</data>
                                        <data name=\"Velocity (m/s)\">gpsV</data>
                                        <data name=\"Direction (°)\">gpsDir</data>
                                        <data name=\"Horizontal Accuracy (m)\">gpsAccuracy</data>
                                        <data name=\"Vertical Accuracy (°)\">gpsZAccuracy</data>
                                    </set>
                                        
                            """
        }
        if sensors.contains(.Gravity){
            exports += """
                                <set name=\"Gravity\">
                                            <data name=\"Time (s)\">graT</data>
                                            <data name=\"Gravity X (m/s^2)\">graX</data>
                                            <data name=\"Gravity Y (m/s^2)\">graY</data>
                                            <data name=\"Gravity Z (m/s^2)\">graZ</data>
                                        </set>
                                        
                                """
        }
        if sensors.contains(.Gyroscope){
            exports += """
                            <set name=\"Gyroscope\">
                                        <data name=\"Time (s)\">gyro_time</data>
                                        <data name=\"X (rad/s)\">gyroX</data>
                                        <data name=\"Y (rad/s)\">gyroY</data>
                                        <data name=\"Z (rad/s)\">gyroZ</data>
                                    </set>
                                        
                            """
        }
        if sensors.contains(.LinearAccelerometer){
            exports += """
                            <set name=\"Linear Accelerometer\">
                                        <data name=\"Time (s)\">lin_acc_time</data>
                                        <data name=\"X (m/s^2)\">lin_accX</data>
                                        <data name=\"Y (m/s^2)\">lin_accY</data>
                                        <data name=\"Z (m/s^2)\">lin_accZ</data>
                                    </set>
                                        
                            """
        }
        if sensors.contains(.Magnetometer){
            exports += """
                            <set name=\"Magnetometer\">
                                        <data name=\"Time (s)\">mag_time</data>
                                        <data name=\"X (µT)\">magX</data>
                                        <data name=\"Y (µT)\">magY</data>
                                        <data name=\"Z (µT)\">magZ</data>
                                    </set>
                                        
                            """
        }
        if sensors.contains(.Proximity){
            exports += """
                            <set name=\"Proximity\">
                                        <data name=\"Time (s)\">prox_time</data>
                                        <data name=\"Distance (cm)\">proxX</data>
                                    </set>
                                        
                            """
        }
        
        return exports
    }
    
    
}
