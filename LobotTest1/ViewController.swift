//
//  ViewController.swift
//  LobotTest1
//
//  Created by sbdev on 2/2/19.
//  Copyright © 2019 any. All rights reserved.
//

import Cocoa
import CoreBluetooth

class ViewController: NSViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    var _centralManager:CBCentralManager?
    var _char:CBCharacteristic?
    var _peripherals:Array<CBPeripheral>?
    var _armControoler:ArmController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let centralQueue: DispatchQueue = DispatchQueue(label: "com.any.centralQueueName", attributes: .concurrent)
        _peripherals = Array<CBPeripheral>()
        _centralManager = CBCentralManager(delegate: self, queue: centralQueue)
        
        // test only, no connection case
        _armControoler = ArmController(peripheral:nil, servoChar:nil)
        _armControoler!.Start()
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
        print(peripheral.name!)
        if (!peripheral.name!.hasPrefix("xArm")) {
            return;
        }
        peripheral.delegate = self
        //let _peripheral = peripheral;
        self._peripherals!.append(peripheral)
        
        _centralManager!.stopScan()
        _centralManager!.connect(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("didConnect")
        peripheral.discoverServices([CBUUID(string: "0xFFF0"), CBUUID(string: "0xFFE0")])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected!")
        
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        for service in peripheral.services! {
            
            if service.uuid == CBUUID(string: "0xFFE0") {
                print("Service: \(service)")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics! {
            print(characteristic)
            if characteristic.uuid == CBUUID(string: "0xFFE1") {
                _char = characteristic;
                _armControoler = ArmController(peripheral:peripheral, servoChar:characteristic)
                _armControoler!.Start()
            }
        }
    }
}

