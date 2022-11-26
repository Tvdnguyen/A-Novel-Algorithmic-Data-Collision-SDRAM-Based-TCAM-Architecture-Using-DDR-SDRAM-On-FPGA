# A-Novel-Algorithmic-Data-Collision-SDRAM-Based-TCAM-Architecture-Using-DDR-SDRAM-On-FPGA
A. SDRAM AS DATA STORAGE
The Data-Collision algorithm for TCAM [20] has achieved better performance optimization due to the exclusive use of SRAM (Static Random-Access Memory) on industrial FPGAs. It also has advantages in scalability and integration compared to traditional TCAMs. Resource optimization is more efficient than other FPGA-based TCAM structures. However, one of the biggest drawbacks of current RAM-based TCAM methods is the modest table size due to the limited address and data width of RAMs; thus, current FPGA-based TCAM architectures have difficulty storing large databases.
Modern SoC FPGA devices powered by Altera contain a DDR3 SDRAM chip with a capacity of 4GB [22]. This memory is comprised of two x16 DDR3 chips for the storage module of a high-speed data acquisition board. [11]. The hard processor system (HPS) SDRAM controller subsystem provides efficient access to external SDRAM for the MPU subsystem, the L3 interconnect, and the FPGA fabric [22], as in figure 1. It offers port and bus configurability, error correction, and power management for external memory.
 ![image](https://user-images.githubusercontent.com/118814159/204074862-b30c4857-502b-4804-be35-6e8a79d9ce9e.png)
Figure 2 shows the Cyclone V SoC Development Kit HPS Physical Memory Map [22] with un-decoded regions. The black arrows point to the accessed address space by a window region. The short blue arrows in the MPU address space indicate that the SDRAM window can shrink depending on the expense of FPGA slaves and boot regions. Since L3, MPU, and FPGA fabric share the same 4GB SDRAM region, careless access to FPGA address space can fatally affect the L3 or MPU while functioning. Thus, it is better to allocate a secure access region for FPGA fabric without affecting the functionality of the L3 and MPU on HPS. Therefore, we configure the boot region to use the bottom 512MB DDR3 memory in this implementation. The remaining upper 512MB is used by FPGA fabric, as shown in figure 2.![image](https://user-images.githubusercontent.com/118814159/204074867-53fae0c0-e252-4593-8d9c-f5a61ad078bf.png)
B. HARDWARE DESIGN ON FPGA
1)	SEGMENTATION MODULE
The key strings are first sent to the segmentation module to make cut-points and partition SDRAM for setting and searching operations. A controller enters setting or searching mode as soon as it receives a set or search flag. The controller takes over all processes of the module. The hardware design of the segmentation module is shown in figure 10.
![image](https://user-images.githubusercontent.com/118814159/204074964-ffe7326a-bbf0-4b5c-8cec-be38129bfc73.png)
	Hardware design of the Segmentation module
In setting mode, the module ensures that it partitions the SDRAM correctly into the aforementioned chained order and that segment mats do not conflict with their address spaces. The module consists of a defined-pattern counter which continuously produces a pre-defined prefix value that is appended to the fragments to form a proper TCAM address. The module applies algorithm 1 to populate the TCAM database into SDRAM. The algorithm's variable 'prefix' represents the prefix that allocates the SDRAM into different segment mats. Variable ‘i’ represents the corresponding key fragments, together with ‘prefix,’ both form a ‘tcam_address.' After forming an accurate address for the memory, the module extracts data at that particular location, based on which the new data is modified before being written into SDRAM. The process repeats till it runs out of fragments. Then, it forms the address for the confirm-database region and stores the key string.

Algorithm 1. Populating Data Algorithm
Input: 
	TCAM Table (tcam_table):
	key
	ruleid
	mask
	priority 
	table depth (D)
	key width (W_key)
	Number of fragments (n_fragments)
Output: SDRAM-based TCAM Table 
	function populating_data(tcam_table,n_fragments)
	    W_(fragments )⇐W_key  / n_fragments
	    prefix⇐ 0
	    for i←0 to i←n_fragments do
	        tcam_address⇐fragmentation(prefix,W_(fragments ),key)
	        old_segment⇐DDR-TCAM[tcam_address]
	        new_segment⇐modify(ruleid,mask,key,priority,
                        old_segment) 
	        DDR-TCAM[tcam_address]⇐new_segment
	        prefix⇐ prefix+1
	    end for
	end function
	function fragmentation(prefix,width,key)
	    address⇐(key "width)
	    tcam_address⇐{prefix,address}
	    return tcam_address
	end function
	function modify(ruleid,mask,key,priority,segment)
	    if (segment is EMPTY) then
	        new_segment⇐{WRITTEN,ruleid,mask,key,priority}
	    else if (segment is WRITTEN) then
	        new_segment⇐{COLLIDED,segment}
	    else if (segment is COLLIDED) then
	        new_segment⇐segment
	    end if
	    return new_segment
	end function
Searching operation is more straightforward than setting. The fragmentation process is the same to produce proper ‘tcam_address’ for data extraction. According to the address, segments are extracted from the SDRAM for further processing. Algorithm 2 shows how the segmentation module iterates through the memory to get segment outputs.
Algorithm 2. Searching for rule ID
Input: 
	Key string (key)
	Key width (W_key)
	Number of fragments (n_fragments)
Output: Rule ID 
	function searching_ruleid(tcam_table,key,n_fragments)
	   W_(fragments )⇐W_key  / n_fragments 
	    prefix⇐0
	    for i←0 to i←n_fragments do
	        tcam_address⇐fragmentation(W_(fragments ),key)
	        segment_out ⇐DDR-TCAM[tcam_address]
	    end for
	end function
	function fragmentation(width,key)
	    address⇐(key "width)
	    tcam_address⇐{prefix,address}
	    prefix⇐prefix+1
	    return tcam_address
	end function
MASKING MODULE
Since the segmentation module extracts segments from SDRAM sequentially, there needs to be a way to handle the data to save search time effectively. The mask module uses the data queueing processing technique in its design. It consists of multiple pipelines to receive and process every data from the SDRAM controller sequentially. As a result, the module always produces results within a certain number of cycles. Figure 11 illustrates how the masking module takes and produces data. The module is designed as a pipelined queue that masks the key string based on the corresponding rule’s mask information.
![image](https://user-images.githubusercontent.com/118814159/204074967-0e4f2603-cf17-4e32-8c98-11b9b32a9fa3.png)
Figure 12 illustrates the hardware design of the mask module. Before proceeding masking process, the module detects and eliminates all the segments in collision or empty states; only valid ones can bypass. Also, rules that repeat are ignored to optimize search time.
 
FIGURE 12.	Hardware design of the Mask module
3)	CONFIRMATION MODULE
The confirmation process ensures that the key string matches the rule database. The module also implements the data queueing technique to optimize the search time.
The confirmation module receives the rule id with its corresponding masked key. The masked key then compares with the attached original one to give the final result. If it matches, it appends the rule ID with a priority number for later address selection. 
Figure 13 describes the hardware architecture of the confirmation module. If two key strings do not match, the module eliminates that rule and waits for the next one; thus, the confirmation module always produces matched rule ids with their priority numbers.
 
FIGURE 13.	Hardware design of the Confirmation module
4)	PRIORITY MODULE
Address or priority selection is the final stage of searching for rule id. It prioritizes rules to be presented at the output. The priority module compares the values attached to each matched rule id and gets the highest-priority match. The result is the rule id that matches the key. If no rule matches the key string, the module shows that the key does not match.
The hardware design of the priority module is illustrated in figure 14. The module uses a feedback mechanism when comparing priority numbers as it receives rule ID inputs sequentially.
 
FIGURE 14.	Hardware design of the Priority module
5)	SDRAM CONTROLLER MODULE
Like the segmentation module, the SDRAM controller is vital in implementing an SDRAM-based TCAM. The module forms a bridge between the whole architecture and DDR SDRAM. The module supports the initialization function besides read and write operations. The state machine for reading, writing, and initializing the SDRAM controller is shown in figure 15.
 
FIGURE 15.	SDRAM operations state machine
The FPGA-to-HPS SDRAM interface exposes the entire 4GB address space to the FPGA fabric. As mentioned in section III, we want our TCAM to access the upper 512MB secure region without making other parts of the chip malfunction. However, it is hard for the system to control the lower and upper bound of the region effectively; therefore, a reliable method is necessary.
The Cyclone V devices provide an Address Span Extender component that offers a common memory management technique, so-called paging [22]. Figure 16 shows how we implement the IP into our system. The IP component provides a memory-mapped window into the upper 512MB that our TCAM masters. Due to the address span extender, the system always safely accesses the provided address space without affecting other regions.
![image](https://user-images.githubusercontent.com/118814159/204074984-d7748b65-9a45-46b2-a8fa-0159c02cb8cf.png)
