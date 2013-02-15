ctech V1
========

C-Tech is a Horizon Digital Economy Research Institute project to explore office and business energy usage
and attitudes.  Code in this repository supports the initial deployment of office energy monitoring equipment.



                                                     +----------+     +----------+
                                        /dev/ttyACM0 |  Monitor-|<----+ Cuircuit |
                                      +-------------->  0501    |     |     1    |
          +----------------+          |              +----------+     +----------+
          |                | +--------|              +----------+     +----------+
          | Sheeva         | |        | /dev/ttyACM1 |  Monitor-|<----+ Circuit  |
          | Plug Computer  +>| USBHub +-------------->  0502    |     |     2    |
          |                | |        |              +----------+     +----------+
          |                | +--------|              +
          +----------------+          | /dev/ttyACM2 +----------+     +----------+
                                      +-------------->  Monitor-|<----+ Circuit  |
                                                     |  05xx    |     |     3    |
                                                     +----------+     +----------+






