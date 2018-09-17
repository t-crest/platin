---
format:          pml-0.1
triple:          armv7-none-none-eabi
bitcode-functions: 
  - name:            sched_c_endless
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [ while.cond ]
        src-hint:        'sched.c:4'
        instructions:    
          - index:           '0'
            opcode:          alloca
          - index:           '1'
            opcode:          alloca
          - index:           '2'
            opcode:          alloca
          - index:           '3'
            opcode:          store
            memmode:         store
          - index:           '4'
            opcode:          call
          - index:           '5'
            opcode:          store
            memmode:         store
          - index:           '6'
            opcode:          call
          - index:           '7'
            opcode:          call
          - index:           '8'
            opcode:          load
            memmode:         load
          - index:           '9'
            opcode:          store
            memmode:         store
          - index:           '10'
            opcode:          br
      - name:            while.cond
        predecessors:    [ while.body, entry ]
        successors:      [ while.body, while.end ]
        loops:           [ while.cond ]
        src-hint:        'sched.c:6'
        instructions:    
          - index:           '0'
            opcode:          load
            memmode:         load
          - index:           '1'
            opcode:          getelementptr
          - index:           '2'
            opcode:          load
            memmode:         load
          - index:           '3'
            opcode:          icmp
          - index:           '4'
            opcode:          br
      - name:            while.body
        predecessors:    [ while.cond ]
        successors:      [ while.cond ]
        loops:           [ while.cond ]
        src-hint:        'sched.c:7'
        instructions:    
          - index:           '0'
            opcode:          load
            memmode:         load
          - index:           '1'
            opcode:          getelementptr
          - index:           '2'
            opcode:          load
            memmode:         load
          - index:           '3'
            opcode:          store
            memmode:         store
          - index:           '4'
            opcode:          br
      - name:            while.end
        predecessors:    [ while.cond ]
        successors:      [  ]
        src-hint:        'sched.c:9'
        instructions:    
          - index:           '0'
            opcode:          load
            memmode:         load
          - index:           '1'
            opcode:          ret
    linkage:         InternalLinkage
  - name:            sched_c_rt_ok
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'sched.c:13'
        instructions:    
          - index:           '0'
            opcode:          alloca
          - index:           '1'
            opcode:          alloca
          - index:           '2'
            opcode:          store
            memmode:         store
          - index:           '3'
            opcode:          call
          - index:           '4'
            opcode:          store
            memmode:         store
          - index:           '5'
            opcode:          call
          - index:           '6'
            opcode:          load
            memmode:         load
          - index:           '7'
            opcode:          ret
    linkage:         InternalLinkage
  - name:            sched_c_dl_ok
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'sched.c:14'
        instructions:    
          - index:           '0'
            opcode:          alloca
          - index:           '1'
            opcode:          alloca
          - index:           '2'
            opcode:          store
            memmode:         store
          - index:           '3'
            opcode:          call
          - index:           '4'
            opcode:          store
            memmode:         store
          - index:           '5'
            opcode:          call
          - index:           '6'
            opcode:          load
            memmode:         load
          - index:           '7'
            opcode:          ret
    linkage:         InternalLinkage
  - name:            sched_c_stop_ok
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'sched.c:15'
        instructions:    
          - index:           '0'
            opcode:          alloca
          - index:           '1'
            opcode:          alloca
          - index:           '2'
            opcode:          store
            memmode:         store
          - index:           '3'
            opcode:          call
          - index:           '4'
            opcode:          store
            memmode:         store
          - index:           '5'
            opcode:          call
          - index:           '6'
            opcode:          load
            memmode:         load
          - index:           '7'
            opcode:          ret
    linkage:         InternalLinkage
...
---
format:          pml-0.1
triple:          armv7-none-none-eabi
relation-graphs: 
  - src:             
      function:        sched_c_endless
      level:           bitcode
    dst:             
      function:        '0'
      level:           machinecode
    nodes:           
      - name:            '0'
        type:            entry
        src-block:       entry
        dst-block:       '0'
        src-successors:  [ '2' ]
        dst-successors:  [ '2' ]
      - name:            '1'
        type:            exit
      - name:            '2'
        type:            progress
        src-block:       while.cond
        dst-block:       '1'
        src-successors:  [ '3', '4' ]
        dst-successors:  [ '3', '4' ]
      - name:            '3'
        type:            progress
        src-block:       while.body
        dst-block:       '2'
        src-successors:  [ '2' ]
        dst-successors:  [ '2' ]
      - name:            '4'
        type:            progress
        src-block:       while.end
        dst-block:       '3'
        src-successors:  [ '1' ]
        dst-successors:  [ '1' ]
    status:          valid
  - src:             
      function:        sched_c_rt_ok
      level:           bitcode
    dst:             
      function:        '1'
      level:           machinecode
    nodes:           
      - name:            '0'
        type:            entry
        src-block:       entry
        dst-block:       '0'
        src-successors:  [ '1' ]
        dst-successors:  [ '1' ]
      - name:            '1'
        type:            exit
    status:          valid
  - src:             
      function:        sched_c_dl_ok
      level:           bitcode
    dst:             
      function:        '2'
      level:           machinecode
    nodes:           
      - name:            '0'
        type:            entry
        src-block:       entry
        dst-block:       '0'
        src-successors:  [ '1' ]
        dst-successors:  [ '1' ]
      - name:            '1'
        type:            exit
    status:          valid
  - src:             
      function:        sched_c_stop_ok
      level:           bitcode
    dst:             
      function:        '3'
      level:           machinecode
    nodes:           
      - name:            '0'
        type:            entry
        src-block:       entry
        dst-block:       '0'
        src-successors:  [ '1' ]
        dst-successors:  [ '1' ]
      - name:            '1'
        type:            exit
    status:          valid
...
---
format:          pml-0.1
triple:          armv7-none-none-eabi
machine-functions: 
  - name:            '0'
    level:           machinecode
    mapsto:          sched_c_endless
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [ '1' ]
        src-hint:        'sched.c:5'
        instructions:    
          - { index: '0', opcode: SUBri, size: 4 }
          - { index: '1', opcode: MOVr, size: 4 }
          - { index: '2', opcode: MOVr, size: 4 }
          - { index: '3', opcode: STRi12, size: 4, memmode: store }
          - { index: '4', opcode: STRi12, size: 4, memmode: store }
          - { index: '5', opcode: STRi12, size: 4, memmode: store }
          - { index: '6', opcode: STRi12, size: 4, memmode: store }
          - { index: '7', opcode: STRi12, size: 4, memmode: store }
          - { index: '8', opcode: B, size: 4, branch-type: unconditional }
      - name:            '1'
        mapsto:          while.cond
        predecessors:    [ '0', '2' ]
        successors:      [ '2', '3' ]
        loops:           [ '1' ]
        src-hint:        'sched.c:6'
        instructions:    
          - { index: '0', opcode: LDRi12, size: 4, memmode: load }
          - { index: '1', opcode: LDRi12, size: 4, memmode: load }
          - { index: '2', opcode: CMPri, size: 4 }
          - { index: '3', opcode: Bcc, size: 4, branch-type: conditional }
          - { index: '4', opcode: B, size: 4, branch-type: unconditional }
      - name:            '2'
        mapsto:          while.body
        predecessors:    [ '1' ]
        successors:      [ '1' ]
        loops:           [ '1' ]
        src-hint:        'sched.c:7'
        instructions:    
          - { index: '0', opcode: LDRi12, size: 4, memmode: load }
          - { index: '1', opcode: LDRi12, size: 4, memmode: load }
          - { index: '2', opcode: STRi12, size: 4, memmode: store }
          - { index: '3', opcode: B, size: 4, branch-type: unconditional }
      - name:            '3'
        mapsto:          while.end
        predecessors:    [ '1' ]
        successors:      [  ]
        src-hint:        'sched.c:9'
        instructions:    
          - { index: '0', opcode: LDRi12, size: 4, memmode: load }
          - { index: '1', opcode: ADDri, size: 4 }
          - { index: '2', opcode: BX_RET, size: 4, branch-type: return }
    linkage:         ExternalLinkage
  - name:            '1'
    level:           machinecode
    mapsto:          sched_c_rt_ok
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'sched.c:13'
        instructions:    
          - { index: '0', opcode: SUBri, size: 4 }
          - { index: '1', opcode: MOVr, size: 4 }
          - { index: '2', opcode: MOVr, size: 4 }
          - { index: '3', opcode: STRi12, size: 4, memmode: store }
          - { index: '4', opcode: STRi12, size: 4, memmode: store }
          - { index: '5', opcode: MOVr, size: 4 }
          - { index: '6', opcode: STRi12, size: 4, memmode: store }
          - { index: '7', opcode: STRi12, size: 4, memmode: store }
          - { index: '8', opcode: ADDri, size: 4 }
          - { index: '9', opcode: BX_RET, size: 4, branch-type: return }
    linkage:         ExternalLinkage
  - name:            '2'
    level:           machinecode
    mapsto:          sched_c_dl_ok
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'sched.c:14'
        instructions:    
          - { index: '0', opcode: SUBri, size: 4 }
          - { index: '1', opcode: MOVr, size: 4 }
          - { index: '2', opcode: MOVr, size: 4 }
          - { index: '3', opcode: STRi12, size: 4, memmode: store }
          - { index: '4', opcode: STRi12, size: 4, memmode: store }
          - { index: '5', opcode: MOVr, size: 4 }
          - { index: '6', opcode: STRi12, size: 4, memmode: store }
          - { index: '7', opcode: STRi12, size: 4, memmode: store }
          - { index: '8', opcode: ADDri, size: 4 }
          - { index: '9', opcode: BX_RET, size: 4, branch-type: return }
    linkage:         ExternalLinkage
  - name:            '3'
    level:           machinecode
    mapsto:          sched_c_stop_ok
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'sched.c:15'
        instructions:    
          - { index: '0', opcode: SUBri, size: 4 }
          - { index: '1', opcode: MOVr, size: 4 }
          - { index: '2', opcode: MOVr, size: 4 }
          - { index: '3', opcode: STRi12, size: 4, memmode: store }
          - { index: '4', opcode: STRi12, size: 4, memmode: store }
          - { index: '5', opcode: MOVr, size: 4 }
          - { index: '6', opcode: STRi12, size: 4, memmode: store }
          - { index: '7', opcode: STRi12, size: 4, memmode: store }
          - { index: '8', opcode: ADDri, size: 4 }
          - { index: '9', opcode: BX_RET, size: 4, branch-type: return }
    linkage:         ExternalLinkage
...
