//
//  ViewController.swift
//  LobotTest1
//
//  Created by sbdev on 2/2/19.
//  Copyright © 2019 any. All rights reserved.
//

import Cocoa
import AppKit
import CoreBluetooth

class ViewController: NSViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    var _centralManager:CBCentralManager?
    var _char:CBCharacteristic?
    var _peripheralArm:CBPeripheral?
    var _peripheralWeight:CBPeripheral?
    var _charWeight:CBCharacteristic?
    var _charWeightCmd:CBCharacteristic?
    var _armControoler:ArmController?
    var _armClawControoler:ArmClawController?
    let _withClaw = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let centralQueue: DispatchQueue = DispatchQueue(label: "com.any.centralQueueName", attributes: .concurrent)
        _centralManager = CBCentralManager(delegate: self, queue: centralQueue)
        
        // test only, no connection case
        //_armControoler = ArmController(peripheral:nil, servoChar:nil)
        //_armControoler!.Start()
        // test only
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        switch central.state {
            
        case .unknown:
            print("Bluetooth status is UNKNOWN")
        case .resetting:
            print("Bluetooth status is RESETTING")
        case .unsupported:
            print("Bluetooth status is UNSUPPORTED")
        case .unauthorized:
            print("Bluetooth status is UNAUTHORIZED")
        case .poweredOff:
            print("Bluetooth status is POWERED OFF")
        case .poweredOn:
            print("Bluetooth status is POWERED ON")
            
            // STEP 3.2: scan for peripherals that we're interested in
            central.scanForPeripherals(withServices:nil)
            
        } // END switch
        
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if(peripheral.name == nil) {
            return;
        }
        //print("found:\(peripheral.name!)")
        if (peripheral.name!.hasPrefix("xArm")) {
            if (_peripheralArm != nil) {
                return;
            }
            _peripheralArm = peripheral;
        } else if (peripheral.name!.hasPrefix("SWAN")) {
            if (_peripheralWeight != nil) {
                return;
            }
            _peripheralWeight = peripheral;
        } else {
            return;
        }
        peripheral.delegate = self
        if (_peripheralArm != nil && _peripheralWeight != nil) {
            _centralManager!.stopScan()
        }
        _centralManager!.connect(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if (peripheral == _peripheralArm) {
            print("didConnect ARM")
            peripheral.discoverServices([CBUUID(string: "0xFFF0"), CBUUID(string: "0xFFE0")])
        }
        if (peripheral == _peripheralWeight) {
            print("didConnect Weight")
            peripheral.discoverServices([
                CBUUID(string:"D618D001-6000-1000-8000-000000000000"),
                CBUUID(string:"0000FFB0-0000-1000-8000-00805F9B34FB")
            ])
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected!")
        
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("didDiscoverService")
        if (peripheral == _peripheralArm) {
            for service in peripheral.services! {
                if service.uuid == CBUUID(string: "0xFFE0") {
                    print("Service: \(service)")
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
        }
        if (peripheral == _peripheralWeight) {
            for service in peripheral.services! {
                print("Service: \(service.uuid)")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if (peripheral == _peripheralArm) {
            for characteristic in service.characteristics! {
                print(characteristic)
                if characteristic.uuid == CBUUID(string: "0xFFE1") {
                    _char = characteristic;
                    if (_withClaw) {
                        _armClawControoler = ArmClawController(peripheral:peripheral, servoChar:characteristic)
                        _armClawControoler!.Start()
                    } else {
                        _armControoler = ArmController(peripheral:peripheral, servoChar:characteristic)
                        _armControoler!.Start()
                    }
                }
            }
        }
        if (peripheral == _peripheralWeight) {
            for characteristic in service.characteristics! {
                print("characteristic: \(characteristic.uuid.uuidString)")
                if (characteristic.uuid.uuidString.hasPrefix("0000FFB1")) {
                    _charWeightCmd = characteristic
                }
                if (characteristic.uuid.uuidString.hasPrefix("0000FFB2")) {
                    _charWeight = characteristic
                    peripheral.setNotifyValue(true, for:_charWeight!)
                    DispatchQueue.main.async {
                        _ = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.ReadWeightTimerCallback), userInfo: nil, repeats: true)
                    }
                }

            }
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        var data = characteristic.value
        //print("didUpdateValue \(data!.hexDescription)")
        data!.removeSubrange(0..<2)
        var number = Int16(bigEndian: data!.withUnsafeBytes { $0.pointee })
        number /= 10
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        if (appDelegate._currentWeight == nil || appDelegate._currentWeight! != number) {
            appDelegate._currentWeight = Int(number)
            print("current weight=\(number)g")
        }
        //ac0400000006cad0 0g
        //ac0404880006ca5c 116g
        //ac04091a0006caf3 332g
    }
    var _timer_cnt:Int = 0;
    @objc func ReadWeightTimerCallback() {
        if (_timer_cnt == 0) {
            var u8array : [UInt8] = [ 0xac, 0x04, 0xfe, 0x00, 0x00, 0xcc, 0xd0 ]
            let nsdata = NSData(bytes: &u8array, length: u8array.count)
            _peripheralWeight!.writeValue(nsdata as Data, for: _charWeightCmd!, type:CBCharacteristicWriteType.withResponse)
        }
        if (_timer_cnt == 1) {
            var u8array : [UInt8] = [ 0xac, 0x04, 0xf7, 0x00, 0x00, 0x00, 0xcc, 0x03 ]
            let nsdata = NSData(bytes: &u8array, length: u8array.count)
            _peripheralWeight!.writeValue(nsdata as Data, for: _charWeightCmd!, type:CBCharacteristicWriteType.withResponse)
        }
        if (_timer_cnt > 10) {
            _peripheralWeight!.readValue(for: _charWeight!)    //(:_charWeight!)
        }
        _timer_cnt = _timer_cnt + 1
    }
}

extension Data {
    var hexDescription: String {
        return reduce("") {$0 + String(format: "%02x", $1)}
    }
}
