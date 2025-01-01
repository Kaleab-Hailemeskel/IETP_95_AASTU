# Remote Train Controller

This is a team project from IETP group 95 **/14 BATCH**. In the following GitHub repo, you will find the remote control app for our suspended monorail train. This Flutter application is used for remote controlling a train. It provides functionalities such as changing the speed, starting and stopping, and changing the direction of the train's movement. These controls are located on the first page of the BottomNavigationBar. The second page displays a list of Bluetooth devices that are proximate to the remote controlling mobile phone.

## Features

- **Speed Control**
- **Start/Stop**
- **Direction Control**
- **Bluetooth Device List**

### Detailed Feature Description

1. **Speed Control**:
   - Users can change the train's speed using the provided controls.

2. **Start/Stop**:
   - The train can be started or stopped using the app.
   - When stopping, the train will gradually decrease its speed instead of stopping abruptly, mimicking real-world train behavior.

3. **Direction Control**:
   - Users can change the direction in which the train moves.
   - For safety and realism, the direction cannot be changed while the train is in motion.

4. **Bluetooth Device List**:
   - The app displays a list of nearby Bluetooth devices.
   - But Users can only connect to these ESP_32 module to control the train.

## Getting Started

### Prerequisites

- [Flutter](https://flutter.dev/docs/get-started/install)
- A mobile device with Bluetooth capabilities.

### Installation

**Clone the repository:**
   ```sh
   git clone (https://github.com/Kaleab-Hailemeskel/IETP_95_AASTU.git)
