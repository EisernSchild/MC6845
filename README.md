--                                                                           --
 S Y N T H E S I Z A B L E    CRTC6845   C O R E
--                                                                           --
www.opencores.org - January 2000
This IP core adheres to the GNU public license.

## VHDL model of MC6845 compatible CRTC                                     
                                                                           
  This model doesn't implement interlace mode. Everything else is          
  (probably) according to original MC6845 data sheet (except VTOTADJ).     
                                                                           
  Implementation in Xilinx Virtex XCV50-6 runs at 50 MHz (character clock).
  With external pixel	generator this CRTC could handle 450MHz pixel rate   
  (see MC6845 datasheet for typical application).	                     
                                                                           
  Author: Damjan Lampret, lampret@opencores.org                            
                                                                           
  TO DO:                                                                   
                                                                           
   - fix REG_INIT and remove non standard signals at topl level entity.    
     Allow fixed registers values (now set with REG_INIT). Anyway cleanup  
     required.                                                             
                                                                           
   - split design in four units (horizontal sync, vertical sync, bus       
     interface and the rest)                                               
                                                                           
   - synthesis with Synplify pending (there are some problems with         
     UNSIGNED and BIT_LOGIC_VECTOR types in some units !)                  
                                                                           
   - testbench                                                             
                                                                           
   - interlace mode support, extend VSYNC for V.Total Adjust value (R5)    
                                                                           
   - verification in a real application                                    
                                                                           