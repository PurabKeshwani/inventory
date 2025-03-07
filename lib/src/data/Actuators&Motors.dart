import 'package:inventory/src/data/model.dart';

class ActuatorsandMotors {
  List<Component> components = [
    Component(
        name: 'Servo motors',
        boxNo: 'AC-01',
        stock: 0), // Assuming stock is 0 since not provided
    Component(
        name: 'L9110 Motor driver',
        boxNo: 'AC-03',
        stock: 0), // Assuming stock is 0 since not provided
    Component(
        name: 'Gear Motor Driver 5V',
        boxNo: 'AC-03',
        stock: 0), // Assuming stock is 0 since not provided
    Component(name: 'Solenoid Pump', boxNo: 'AC-02', stock: 2),
    Component(name: 'Solenoid Lock', boxNo: 'AC-02', stock: 2),
    Component(name: 'Relay module', boxNo: 'AC-03', stock: 9),
    Component(name: 'Solid state Relay', boxNo: 'AC-03', stock: 1),
    Component(name: 'N20 Encoded DC Motor', boxNo: 'AC-01', stock: 1),
    Component(name: 'L298 Driver', boxNo: 'AC-03', stock: 1),
    Component(name: 'Stepper Motor Driver', boxNo: 'AC-03', stock: 1)
  ];
}
