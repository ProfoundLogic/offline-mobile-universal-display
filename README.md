# Profound UI sample offline app using Universal Display Program

<!-- TOC depthFrom:2 -->

- [Requirements](#requirements)
- [Installation](#installation)
    - [Javascript Program](#Javascript-Program)
    - [Files](#Files)
    - [IBM i](#ibm-i)
- [Running the offline app](#running-the-offline-app)
- [The structure of an offline app](#the-structure-of-an-offline-app)
    - [Overview](#overview)
    - [Filenames and location](#filenames-and-location)
    - [Required methods](#required-methods)
- [Sample code](#sample-code)

<!-- /TOC -->

Working sample code for an offline Profound UI mobile application and its corresponding Universal Display program web service. When installed, files that make up a simple shopping app will be downloaded to the Profound UI mobile app from a server and then executed in a disconnected, "offline" manner. Products can be "purchased" with no network connection in place between the mobile device and the back-end web service. Once a connection is re-established, the queued orders can be sent to the Universal Display web service, where they will be written to tables on the IBM i.

This example project is a fork of the offline-mobile-sample project with the Profound.js web service replaced by a Profound UI Universal Display program.

## Requirements

- The Profound UI mobile app installed from the iOS or Android app store
- Profound UI installed on IBM i
- An IBM i

## Installation

Follow these instructions to produce a working offline app.
### Javascript Program

- Edit the puimobile_default.json file and replace [SYNC_USER] and [SYNC_PASSWORD] with a valid username and password
- Move `puimobile_default.js` and `puimobile_default.json` to the Profound UI "user data" JavaScript folder (`<profound_js>/htdocs/profoundui/userdata/js`).  These files comprise the actual offline app that will be downloaded to the mobile device and run.

### Files

- Create a library to contain your sample data.
- Create the products, order header, and order detail files, by executing the included `PRODUCTSP.sql`, `ORDHDR.sql` and `ORDDTL.sql` scripts.  Be sure to edit the scripts to contain your own library name.  SQL scripts can be run either from IBM Access Client Solutions on your PC or by issuing a statement on the IBM i like

```
> RUNSQLSTM SRCSTMF('QSQLSRC/ORDDTL.sql') COMMIT(*NONE) NAMING(*SQL)
```
### IBM i 
- Use the provided source files to create the following
- - OFFLINEMBD.DSPF - Universal Display file for the sync web service
- - OFFLINEMB.SQLRPGLE - The rpg program for the sync web service
- - OFFLINEMBC.CLLE - A CLLE program to set the library list
- Copy and Paste the source code into RDI or FTP them to your IBM i
- Edit the ADDLIBLE commands in OFFLINEMBC as needed
- Compile the display file followed by the RPG and CL programs
- Use the PUIWRKMAP command to add your mapping for the Universal Display File. Click "Add" and use these values:
```
URI MAPPING: /offlinemb_sync
LIBRARY: your-library
PROGRAM: OFFLINEMBC
SIGNON: No
```
If you cannot use PUIWRKMAP, you can add these to the PUIMAPP table yourself. Details can be found under Using the Web Connector.

## Running the offline app

In the Profound UI mobile app, define a connection that points to your system and the correct port for your Profoudn UI instance. On the connection configuration screen, slide the `Offline mode` switch to `on`. Then tap Save.

Tap the Sync icon to do an initial sync which will copy the offlinemobile_default.js and offlinemobile.json files to your device.

Tap on the connection name to run the app.

## The structure of an offline app

This section describes what is involved in creating a Profound UI offline-capable mobile app.

### Overview

A Profound UI "offline" mobile application consists of a JavaScript program and a Rich Display file (in the form of a JSON file).  These files are copied to a mobile device when the device is synced to the server. Once synced, the application can be run at will, even when the device is disconnected from the server. Any data collected by the app will be stored locally on the device until the next sync occurs, at which time the stored data will be sent to the server for processing.

### Filenames and location

The name of the mobile application files will vary depending on the connection's parameter property. Historically, Profound UI mobile connections have had an optional parameter property to be used by the remote system as a way of controlling which back-end program should be run. If no parameter property is specified, the mobile app filenames should be `puimobile_default.js` and `puimobile_default.json`. If a parameter is specified for a connection, then the parameter will become part of the filename; e.g., an offline app with a connection parameter of `abc` should be named `puimobile_abc.js` and `puimobile_abc.json`.  These files are stored in the `userdata/js` folder of a Profound UI installation.

### Required methods

The offline mobile application can do anything you'd like, but it must provide three methods that will be called by the Profound UI mobile app. See the [sample code](htdocs-profoundui-userdata-js/) for a working implementation example.

- `sync(connection, callback)` This method will be called when the connection's sync button is tapped on the connections screen, and should contain your code for sending to the server data that was collected since the previous sync. It contains two parameters.
  - `connection` contains connection information for reaching the server, such as the server name, port, etc.
  - `callback` is a Profound UI function that should be called once the sync has completed.
- `run(displayData, connection, callback)` This method will be called when the connection is tapped on the connections screen, and contains the code for your actual offline app. It contains three parameters.
  - `displayData` contains the Rich Display screen data for the offline application (the `puimobile_default.json` data), and should be sent along to `pui.show()` for rendering, via its `meta` property.
  - `connection` contains connection information for reaching the server, in case your offline app wants to directly contact the server outside of the sync method.
  - `callback` is a Profound UI function that should be called to exit your application and return to the connections screen.
- `isSyncNeeded()` This method is used to tell the Profound UI mobile app if any offline data exists in your app that needs to be synced with the server. A value of `true` will color the sync button amber to indicate that a sync is needed, and `false` will color it green.

## Sample code

The provided [sample code](htdocs-profoundui-userdata-js/) for a Profound UI offline mobile app is a very simple but functioning shopping cart app. Products are displayed with a "Buy" button next to each one. Tapping a product button increments the number of units to be "purchased". Tapping the "Checkout" button saves the shopping cart and exits back to the connections screen.

If any items were "purchased", notice that the sync button will have changed from green to amber to indicate that offline data exists that can be synced to the server.

Tapping the sync button causes the app to send the queued product orders to the server (in this case a Profound UI Universal Display web service), which in turn writes them to order header and detail tables on an IBM i. The web service then sends a fresh copy of the product table back to the mobile application, and the sync is complete.