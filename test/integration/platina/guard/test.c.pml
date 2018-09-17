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
            opcode:          ret
    linkage:         ExternalLinkage
  - name:            main
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:3'
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
            opcode:          store
            memmode:         store
          - index:           '5'
            opcode:          call
          - index:           '6'
            opcode:          store
            memmode:         store
          - index:           '7'
            opcode:          call
          - index:           '8'
            opcode:          load
            memmode:         load
          - index:           '9'
            opcode:          load
            memmode:         load
          - index:           '10'
            opcode:          ret
    linkage:         ExternalLinkage
  - name:            c_entry
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [ if.then, if.else ]
        src-hint:        'test.c:10'
        instructions:    
          - index:           '0'
            opcode:          alloca
          - index:           '1'
            opcode:          store
            memmode:         store
          - index:           '2'
            opcode:          call
          - index:           '3'
            opcode:          load
            memmode:         load
          - index:           '4'
            opcode:          icmp
          - index:           '5'
            opcode:          br
      - name:            if.then
        predecessors:    [ entry ]
        successors:      [  ]
        src-hint:        'test.c:13'
        instructions:    
          - index:           '0'
            opcode:          ret
      - name:            if.else
        predecessors:    [ entry ]
        successors:      [ while.body ]
        src-hint:        'test.c:14'
        instructions:    
          - index:           '0'
            opcode:          call
          - index:           '1'
            opcode:          br
      - name:            while.body
        predecessors:    [ if.else, while.body ]
        successors:      [ while.body ]
        loops:           [ while.body ]
        src-hint:        'test.c:16'
        instructions:    
          - index:           '0'
            opcode:          br
    linkage:         ExternalLinkage
modelfacts:      
  - program-point:   
      function:        c_entry
      block:           if.else
    origin:          platina.bc
    level:           bitcode
    type:            guard
    expression:      'False'
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
        src-successors:  [ '2', '3' ]
        dst-successors:  [ '2', '3' ]
      - name:            '1'
        type:            exit
      - name:            '2'
        type:            progress
        src-block:       if.else
        dst-block:       '2'
        src-successors:  [ '4' ]
        dst-successors:  [ '4' ]
      - name:            '3'
        type:            progress
        src-block:       if.then
        dst-block:       '1'
        src-successors:  [ '1' ]
        dst-successors:  [ '1' ]
      - name:            '4'
        type:            progress
        src-block:       while.body
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
        src-hint:        'test.c:1'
        instructions:    
          - { index: '0', opcode: BX_RET, size: 4, branch-type: return }
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
        src-hint:        'test.c:7'
        instructions:    
          - { index: '0', opcode: SUBri, size: 4 }
          - { index: '1', opcode: MOVr, size: 4 }
          - { index: '2', opcode: MOVr, size: 4 }
          - { index: '3', opcode: MOVi, size: 4 }
          - { index: '4', opcode: STRi12, size: 4, memmode: store }
          - { index: '5', opcode: STRi12, size: 4, memmode: store }
          - { index: '6', opcode: STRi12, size: 4, memmode: store }
          - { index: '7', opcode: MOVr, size: 4 }
          - { index: '8', opcode: STRi12, size: 4, memmode: store }
          - { index: '9', opcode: STRi12, size: 4, memmode: store }
          - { index: '10', opcode: ADDri, size: 4 }
          - { index: '11', opcode: BX_RET, size: 4, branch-type: return }
    linkage:         ExternalLinkage
  - name:            '2'
    level:           machinecode
    mapsto:          c_entry
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [ '1', '2' ]
        src-hint:        'test.c:12'
        instructions:    
          - { index: '0', opcode: SUBri, size: 4 }
          - { index: '1', opcode: MOVr, size: 4 }
          - { index: '2', opcode: STRi12, size: 4, memmode: store }
          - { index: '3', opcode: CMPri, size: 4 }
          - { index: '4', opcode: STRi12, size: 4, memmode: store }
          - { index: '5', opcode: Bcc, size: 4, branch-type: conditional }
          - { index: '6', opcode: B, size: 4, branch-type: unconditional }
      - name:            '1'
        mapsto:          if.then
        predecessors:    [ '0' ]
        successors:      [  ]
        src-hint:        'test.c:13'
        instructions:    
          - { index: '0', opcode: MOVi, size: 4 }
          - { index: '1', opcode: ADDri, size: 4 }
          - { index: '2', opcode: BX_RET, size: 4, branch-type: return }
      - name:            '2'
        mapsto:          if.else
        predecessors:    [ '0' ]
        successors:      [ '3' ]
        src-hint:        'test.c:14'
        instructions:    
          - { index: '0', opcode: B, size: 4, branch-type: unconditional }
      - name:            '3'
        mapsto:          while.body
        predecessors:    [ '2', '3' ]
        successors:      [ '3' ]
        loops:           [ '3' ]
        src-hint:        'test.c:16'
        instructions:    
          - { index: '0', opcode: B, size: 4, branch-type: unconditional }
    linkage:         ExternalLinkage
...
