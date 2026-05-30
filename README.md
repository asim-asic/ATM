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
