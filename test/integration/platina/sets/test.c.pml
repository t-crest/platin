---
format:          pml-0.1
triple:          armv7-none-none-eabi
bitcode-functions: 
  - name:            _exit
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:1'
        instructions:    
          - index:           '0'
            opcode:          alloca
          - index:           '1'
            opcode:          store
            memmode:         store
          - index:           '2'
            opcode:          call
            intrinsic:       true
          - index:           '3'
            opcode:          unreachable
    linkage:         ExternalLinkage
  - name:            main
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:2'
        instructions:    
          - index:           '0'
            opcode:          alloca
          - index:           '1'
            opcode:          store
            memmode:         store
          - index:           '2'
            opcode:          call
            callees:         [ _exit ]
          - index:           '3'
            opcode:          unreachable
    linkage:         ExternalLinkage
  - name:            c_entry
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [ while.cond ]
        src-hint:        'test.c:6'
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
            intrinsic:       true
          - index:           '4'
            opcode:          call
            intrinsic:       true
          - index:           '5'
            opcode:          store
            memmode:         store
          - index:           '6'
            opcode:          br
      - name:            while.cond
        predecessors:    [ while.body, entry ]
        successors:      [ while.body, while.end ]
        loops:           [ while.cond ]
        src-hint:        'test.c:9'
        instructions:    
          - index:           '0'
            opcode:          load
            memmode:         load
          - index:           '1'
            opcode:          icmp
          - index:           '2'
            opcode:          br
      - name:            while.body
        predecessors:    [ while.cond ]
        successors:      [ while.cond ]
        loops:           [ while.cond ]
        src-hint:        'test.c:9'
        instructions:    
          - index:           '0'
            opcode:          call
            intrinsic:       true
          - index:           '1'
            opcode:          load
            memmode:         load
          - index:           '2'
            opcode:          add
          - index:           '3'
            opcode:          store
            memmode:         store
          - index:           '4'
            opcode:          br
      - name:            while.end
        predecessors:    [ while.cond ]
        successors:      [  ]
        src-hint:        'test.c:13'
        instructions:    
          - index:           '0'
            opcode:          load
            memmode:         load
          - index:           '1'
            opcode:          ret
    linkage:         ExternalLinkage
modelfacts:      
  - program-point:   
      function:        c_entry
      block:           while.cond
    origin:          platina.bc
    level:           bitcode
    type:            lbound
    expression:      'NUM_TASKS - set_min(NEXT_SCHED_PRIO_SET)'
...
---
format:          pml-0.1
triple:          armv7-none-none-eabi
relation-graphs: 
  - src:             
      function:        _exit
      level:           bitcode
    dst:             
      function:        '0'
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
      function:        main
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
      function:        c_entry
      level:           bitcode
    dst:             
      function:        '2'
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
...
---
format:          pml-0.1
triple:          armv7-none-none-eabi
machine-functions: 
  - name:            '0'
    level:           machinecode
    mapsto:          _exit
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [  ]
        instructions:    
          - { index: '0', opcode: tSUBspi, size: 2 }
          - { index: '1', opcode: tMOVr, size: 2 }
          - { index: '2', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '3', opcode: tSTRspi, size: 2, memmode: store }
    linkage:         ExternalLinkage
  - name:            '1'
    level:           machinecode
    mapsto:          main
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:2'
        instructions:    
          - { index: '0', opcode: tPUSH, size: 2, memmode: store }
          - { index: '1', opcode: tMOVr, size: 2 }
          - { index: '2', opcode: tSUBspi, size: 2 }
          - { index: '3', opcode: tMOVi8, size: 2 }
          - { index: '4', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '5', opcode: tMOVi8, size: 2 }
          - { index: '6', opcode: tBL, callees: [ _exit ], size: 4, branch-type: call }
    linkage:         ExternalLinkage
  - name:            '2'
    level:           machinecode
    mapsto:          c_entry
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [ '1' ]
        src-hint:        'test.c:8'
        instructions:    
          - { index: '0', opcode: tSUBspi, size: 2 }
          - { index: '1', opcode: tMOVr, size: 2 }
          - { index: '2', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '3', opcode: tMOVi8, size: 2 }
          - { index: '4', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '5', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '6', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '1'
        mapsto:          while.cond
        predecessors:    [ '0', '2' ]
        successors:      [ '2', '3' ]
        loops:           [ '1' ]
        src-hint:        'test.c:9'
        instructions:    
          - { index: '0', opcode: t2MOVi16, size: 4 }
          - { index: '1', opcode: t2MOVTi16, size: 4 }
          - { index: '2', opcode: tLDRi, size: 2, memmode: load }
          - { index: '3', opcode: tCMPi8, size: 2 }
          - { index: '4', opcode: tBcc, size: 2, branch-type: conditional }
          - { index: '5', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '2'
        mapsto:          while.body
        predecessors:    [ '1' ]
        successors:      [ '1' ]
        loops:           [ '1' ]
        src-hint:        'test.c:11'
        instructions:    
          - { index: '0', opcode: tLDRspi, size: 2, memmode: load }
          - { index: '1', opcode: tADDi8, size: 2 }
          - { index: '2', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '3', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '3'
        mapsto:          while.end
        predecessors:    [ '1' ]
        successors:      [  ]
        src-hint:        'test.c:13'
        instructions:    
          - { index: '0', opcode: tLDRspi, size: 2, memmode: load }
          - { index: '1', opcode: tADDspi, size: 2 }
          - { index: '2', opcode: tBX_RET, size: 2, branch-type: return }
    linkage:         ExternalLinkage
...
