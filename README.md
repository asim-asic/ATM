# System Verilog ATM Design

## Overview
Asynchronous Transfer Mode (ATM) is a communication protocol for digital
transmission of multiple types of traffic, including voice, video, and data.
This project implements an ATM switching node modeled entirely in
SystemVerilog.

The primary goal of this project is to deeply understand and apply core
SystemVerilog design concepts by building a real, synthesizable hardware
design from scratch.

> **Note:** This is a living document. Design details, module descriptions,
> and implementation notes will be updated progressively as the project
> develops through each phase — from documentation → coding → simulation
> → debugging → linting → synthesis.

## ATM Protocol Background

### What is ATM?
Asynchronous Transfer Mode (ATM) is a telecommunication standard defined by ANSI and ITU-T for digital transmission of multiple types of traffic. It is a cell switching technology that combines features of both circuit switching and packet switching networks using asynchronous time-division multiplexing.

ATM was developed in late 1980s to meet the needs of Broadband ISDN(B-ISDN) and was designed to carry voice, video, and data over the same network simultaneously.


### The ATM Cell
The fundamental unit of ATM is the **cell** - a fixed size 53-byte packet.

| Field   | Size     |
|---------|----------|
| Header  | 5 bytes  |
| Payload | 48 bytes |
| Total   | 53 bytes |

All cells are the same fixed size. This eliminates jitter - unpridictable delays caused by variable-lenght packets - which is critical for real time traffic like voice and video.

---

### Cell Formats - UNI and NNI

ATM defines two cell formats:

- **UNI (User-to-Network Interface)** — used between an end-user device
  and the ATM network switch
- **NNI (Network-to-Network Interface)** — used between ATM switches
  inside the network

| Field | UNI      | NNI      |
|-------|----------|----------|
| GFC   | 4 bits   | ❌ removed |
| VPI   | 8 bits   | 12 bits  |
| VCI   | 16 bits  | 16 bits  |
| PT    | 3 bits   | 3 bits   |
| CLP   | 1 bit    | 1 bit    |
| HEC   | 8 bits   | 8 bits   |

In NNI format, the 4-bit GFC field is removed and its bits are given to
the VPI field, extending it from 8 to 12 bits.

---

### Header Fields

- **GFC — Generic Flow Control** — Manages flow between user and network.
  Only present in UNI. In practice always set to `0000`.
- **VPI — Virtual Path Identifier** — Groups multiple channels into one
  logical virtual path.
- **VCI — Virtual Channel Identifier** — Identifies a specific channel
  within a virtual path.
- **PT — Payload Type** — Indicates whether the cell carries user data or
  network management data. Also signals congestion.
- **CLP — Cell Loss Priority** — If set to `1`, this cell is dropped first
  when the network is congested.
- **HEC — Header Error Control** — 8-bit CRC checksum over the header only.
  Polynomial: X⁸ + X² + X + 1.

---

## Virtual Circuits

ATM is connection-oriented. Before any data flows, a virtual circuit must
be established between two endpoints.

- **PVC — Permanent Virtual Circuit** — Pre-configured dedicated connection.
- **SVC — Switched Virtual Circuit** — Created dynamically only for the
  duration of a session.

Switching in ATM works by **label swapping** — as a cell passes through
each switch, the VPI/VCI values in the header are replaced with new values
for the next hop. The switch simply looks up the incoming VPI/VCI in a
table to determine the outgoing port and new VPI/VCI values.

---

### ATM Protocol Layers

ATM maps to the bottom three layers of the OSI model:

```
+------------------------------+
|     Higher Layer Services    |  Voice, Video, IP, Data
+------------------------------+
|  AAL - ATM Adaptation Layer  |  Segmentation & Reassembly
+------------------------------+
|         ATM Layer            |  Cell switching, VPI/VCI, multiplexing
+------------------------------+
|       Physical Layer         |  Bit transmission over SONET/SDH
+------------------------------+
```
- **Physical Layer** — Converts cells into a bitstream and manages
  transmission over the physical medium.
- **ATM Layer** — Handles cell switching, multiplexing, congestion control,
  and cell header processing using VPI/VCI information.
- **AAL — ATM Adaptation Layer** — Isolates higher-layer protocols from ATM
  details. Segments large data units into 48-byte payloads and reassembles
  them at the destination.

---

### AAL Types

| AAL Type | Used For                              |
|----------|---------------------------------------|
| AAL1     | Constant Bit Rate (CBR) — voice, circuit emulation |
| AAL2     | Variable Bit Rate (VBR) — compressed voice/video  |
| AAL5     | Data — most widely used today         |

## Design Architecture

### Overview

The design implements a quad ATM user-to-network interface and forwarding
node. It is a configurable NxP port forwarding switch that receives ATM
cells on N input ports, looks up the correct output port using a VPI/VCI
lookup table, and forwards the cell to the correct P output port.

By default the design is a **4x4 switch** — 4 input ports and 4 output
ports. Using `+define` invocation options at compile time, it can be
scaled to any NxP configuration.

---

### Module Descriptions

#### `squat` — Top Level Switch Module

The top-level ATM switch module. It instantiates and connects all
sub-modules together. It receives incoming ATM cells on NumRx input
ports, uses an internal lookup table to determine the correct output
port based on the VPI/VCI values in the cell header, and forwards the
cell to the correct output port among NumTx transmit ports. It also
exposes a CPU management interface for configuring the lookup table at
runtime.

| Port  | Direction | Description                        |
|-------|-----------|------------------------------------|
| Rx    | Input     | Array of NumRx Utopia receive interfaces  |
| Tx    | Output    | Array of NumTx Utopia transmit interfaces |
| mif   | Input     | CPU management interface           |
| rst   | Input     | Asynchronous reset                 |
| clk   | Input     | Clock signal                       |

#### `utopial_atm_rx` — ATM Receiver Module

The ATM receiver module listens on a single Utopia Level 1 receive
interface and collects incoming bytes one at a time. It uses a finite
state machine (FSM) to assemble a complete 53-byte ATM cell from the
incoming byte stream. Once a complete cell is assembled, it is copied
to the cell buffer and marked as valid for the switch fabric to process.

The FSM cycles through the following states:

| State      | Description                              |
|------------|------------------------------------------|
| `reset`    | Initial state — waits for activity       |
| `soc`      | Detects Start of Cell signal             |
| `vpi_vci`  | Reads VPI and VCI header bytes           |
| `vci`      | Continues reading VCI field              |
| `vci_clp_pt` | Reads VCI, CLP and PT fields           |
| `hec`      | Reads Header Error Control byte          |
| `payload`  | Reads 48 payload bytes                   |
| `ack`      | Acknowledges complete cell reception     |

| Port | Direction | Description                    |
|------|-----------|--------------------------------|
| Rx   | Interface | Utopia CoreReceive interface   |

