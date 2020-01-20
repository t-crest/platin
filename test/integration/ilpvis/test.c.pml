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
        src-hint:        'test.c:0'
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
            opcode:          ret
    linkage:         ExternalLinkage
  - name:            callee
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [ while.body ]
        src-hint:        'test.c:5'
        instructions:    
          - index:           '0'
            opcode:          alloca
          - index:           '1'
            opcode:          br
      - name:            while.body
        predecessors:    [ entry, while.body ]
        successors:      [ while.body ]
        loops:           [ while.body ]
        src-hint:        'test.c:5'
        instructions:    
          - index:           '0'
            opcode:          br
    linkage:         ExternalLinkage
  - name:            c_entry
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [ if.then, if.else ]
        src-hint:        'test.c:8'
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
            opcode:          load
            memmode:         load
          - index:           '5'
            opcode:          icmp
          - index:           '6'
            opcode:          br
      - name:            if.then
        predecessors:    [ entry ]
        successors:      [ return ]
        src-hint:        'test.c:11'
        instructions:    
          - index:           '0'
            opcode:          store
            memmode:         store
          - index:           '1'
            opcode:          br
      - name:            if.else
        predecessors:    [ entry ]
        successors:      [ if.end ]
        src-hint:        'test.c:13'
        instructions:    
          - index:           '0'
            opcode:          call
            callees:         [ callee ]
          - index:           '1'
            opcode:          br
      - name:            if.end
        predecessors:    [ if.else ]
        successors:      [ return ]
        src-hint:        'test.c:19'
        instructions:    
          - index:           '0'
            opcode:          store
            memmode:         store
          - index:           '1'
            opcode:          br
      - name:            return
        predecessors:    [ if.end, if.then ]
        successors:      [  ]
        src-hint:        'test.c:20'
        instructions:    
          - index:           '0'
            opcode:          load
            memmode:         load
          - index:           '1'
            opcode:          ret
    linkage:         ExternalLinkage
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
      function:        callee
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
        src-block:       while.body
        dst-block:       '1'
        src-successors:  [ '2' ]
        dst-successors:  [ '2' ]
    status:          valid
  - src:             
      function:        c_entry
      level:           bitcode
    dst:             
      function:        '3'
      level:           machinecode
    nodes:           
      - name:            '0'
        type:            entry
        src-block:       entry
        dst-block:       '0'
        src-successors:  [ '2', '3' ]
        dst-successors:  [ '2', '3' ]
      - name:            '1'
        type:            exit
      - name:            '2'
        type:            progress
        src-block:       if.else
        dst-block:       '2'
        src-successors:  [ '5' ]
        dst-successors:  [ '5' ]
      - name:            '3'
        type:            progress
        src-block:       if.then
        dst-block:       '1'
        src-successors:  [ '4' ]
        dst-successors:  [ '4' ]
      - name:            '4'
        type:            progress
        src-block:       return
        dst-block:       '4'
        src-successors:  [ '1' ]
        dst-successors:  [ '1' ]
      - name:            '5'
        type:            progress
        src-block:       if.end
        dst-block:       '3'
        src-successors:  [ '4' ]
        dst-successors:  [ '4' ]
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
          - { index: '0', opcode: tSUBspi, size: 2 }
          - { index: '1', opcode: tMOVi8, size: 2 }
          - { index: '2', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '3', opcode: tMOVi8, size: 2 }
          - { index: '4', opcode: tADDspi, size: 2 }
          - { index: '5', opcode: tBX_RET, size: 2, branch-type: return }
    linkage:         ExternalLinkage
  - name:            '2'
    level:           machinecode
    mapsto:          callee
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [ '1' ]
        src-hint:        'test.c:5'
        instructions:    
          - { index: '0', opcode: tSUBspi, size: 2 }
          - { index: '1', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '1'
        mapsto:          while.body
        predecessors:    [ '0', '1' ]
        successors:      [ '1' ]
        loops:           [ '1' ]
        src-hint:        'test.c:5'
        instructions:    
          - { index: '0', opcode: tB, size: 2, branch-type: unconditional }
    linkage:         ExternalLinkage
  - name:            '3'
    level:           machinecode
    mapsto:          c_entry
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [ '1', '2' ]
        src-hint:        'test.c:10'
        instructions:    
          - { index: '0', opcode: tPUSH, size: 2, memmode: store }
          - { index: '1', opcode: tMOVr, size: 2 }
          - { index: '2', opcode: tSUBspi, size: 2 }
          - { index: '3', opcode: tMOVr, size: 2 }
          - { index: '4', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '5', opcode: tLDRspi, size: 2, memmode: load }
          - { index: '6', opcode: tCMPi8, size: 2 }
          - { index: '7', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '8', opcode: tBcc, size: 2, branch-type: conditional }
          - { index: '9', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '1'
        mapsto:          if.then
        predecessors:    [ '0' ]
        successors:      [ '4' ]
        src-hint:        'test.c:11'
        instructions:    
          - { index: '0', opcode: tMOVi8, size: 2 }
          - { index: '1', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '2', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '2'
        mapsto:          if.else
        predecessors:    [ '0' ]
        successors:      [ '3' ]
        src-hint:        'test.c:13'
        instructions:    
          - { index: '0', opcode: tBL, callees: [ callee ], size: 4, branch-type: call }
          - { index: '1', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '2', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '3'
        mapsto:          if.end
        predecessors:    [ '2' ]
        successors:      [ '4' ]
        src-hint:        'test.c:19'
        instructions:    
          - { index: '0', opcode: tMOVi8, size: 2 }
          - { index: '1', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '2', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '4'
        mapsto:          return
        predecessors:    [ '3', '1' ]
        successors:      [  ]
        src-hint:        'test.c:20'
        instructions:    
          - { index: '0', opcode: tLDRspi, size: 2, memmode: load }
          - { index: '1', opcode: tADDspi, size: 2 }
          - { index: '2', opcode: tPOP_RET, size: 2, branch-type: return }
    linkage:         ExternalLinkage
...
