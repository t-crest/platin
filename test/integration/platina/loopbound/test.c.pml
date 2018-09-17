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
        src-hint:        'test.c:2'
        instructions:    
          - index:           '0'
            opcode:          call
            callees:         [ _exit ]
          - index:           '1'
            opcode:          ret
    linkage:         ExternalLinkage
  - name:            c_entry
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [ while.cond ]
        src-hint:        'test.c:14'
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
            opcode:          call
          - index:           '6'
            opcode:          store
            memmode:         store
          - index:           '7'
            opcode:          call
          - index:           '8'
            opcode:          store
            memmode:         store
          - index:           '9'
            opcode:          br
      - name:            while.cond
        predecessors:    [ while.body, entry ]
        successors:      [ while.body, while.end ]
        loops:           [ while.cond ]
        src-hint:        'test.c:18'
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
        src-hint:        'test.c:18'
        instructions:    
          - index:           '0'
            opcode:          call
          - index:           '1'
            opcode:          load
            memmode:         load
          - index:           '2'
            opcode:          getelementptr
          - index:           '3'
            opcode:          load
            memmode:         load
          - index:           '4'
            opcode:          store
            memmode:         store
          - index:           '5'
            opcode:          load
            memmode:         load
          - index:           '6'
            opcode:          add
          - index:           '7'
            opcode:          store
            memmode:         store
          - index:           '8'
            opcode:          br
      - name:            while.end
        predecessors:    [ while.cond ]
        successors:      [  ]
        src-hint:        'test.c:23'
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
    expression:      '5'
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
        src-hint:        'test.c:2'
        instructions:    
          - { index: '0', opcode: STMDB_UPD, size: 4, memmode: store }
          - { index: '1', opcode: BL_pred, callees: [ _exit ], size: 4, 
              branch-type: call }
          - { index: '2', opcode: MOVi, size: 4 }
          - { index: '3', opcode: LDMIA_RET, size: 4, branch-type: return }
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
        src-hint:        'test.c:16'
        instructions:    
          - { index: '0', opcode: SUBri, size: 4 }
          - { index: '1', opcode: MOVr, size: 4 }
          - { index: '2', opcode: STRi12, size: 4, memmode: store }
          - { index: '3', opcode: MOVi, size: 4 }
          - { index: '4', opcode: STRi12, size: 4, memmode: store }
          - { index: '5', opcode: MOVi16, size: 4 }
          - { index: '6', opcode: MOVTi16, size: 4 }
          - { index: '7', opcode: STRi12, size: 4, memmode: store }
          - { index: '8', opcode: STRi12, size: 4, memmode: store }
          - { index: '9', opcode: B, size: 4, branch-type: unconditional }
      - name:            '1'
        mapsto:          while.cond
        predecessors:    [ '0', '2' ]
        successors:      [ '2', '3' ]
        loops:           [ '1' ]
        src-hint:        'test.c:18'
        instructions:    
          - { index: '0', opcode: LDRi12, size: 4, memmode: load }
          - { index: '1', opcode: CMPri, size: 4 }
          - { index: '2', opcode: Bcc, size: 4, branch-type: conditional }
          - { index: '3', opcode: B, size: 4, branch-type: unconditional }
      - name:            '2'
        mapsto:          while.body
        predecessors:    [ '1' ]
        successors:      [ '1' ]
        loops:           [ '1' ]
        src-hint:        'test.c:20'
        instructions:    
          - { index: '0', opcode: LDRi12, size: 4, memmode: load }
          - { index: '1', opcode: LDRi12, size: 4, memmode: load }
          - { index: '2', opcode: STRi12, size: 4, memmode: store }
          - { index: '3', opcode: LDRi12, size: 4, memmode: load }
          - { index: '4', opcode: ADDri, size: 4 }
          - { index: '5', opcode: STRi12, size: 4, memmode: store }
          - { index: '6', opcode: B, size: 4, branch-type: unconditional }
      - name:            '3'
        mapsto:          while.end
        predecessors:    [ '1' ]
        successors:      [  ]
        src-hint:        'test.c:23'
        instructions:    
          - { index: '0', opcode: LDRi12, size: 4, memmode: load }
          - { index: '1', opcode: ADDri, size: 4 }
          - { index: '2', opcode: BX_RET, size: 4, branch-type: return }
    linkage:         ExternalLinkage
...
