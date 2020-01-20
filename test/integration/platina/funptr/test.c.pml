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
        src-hint:        'test.c:3'
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
        src-hint:        'test.c:4'
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
  - name:            f2
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:13'
        instructions:    
          - index:           '0'
            opcode:          store
            memmode:         store
          - index:           '1'
            opcode:          load
            memmode:         load
          - index:           '2'
            opcode:          ret
    linkage:         ExternalLinkage
  - name:            f3
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [ for.cond ]
        src-hint:        'test.c:18'
        instructions:    
          - index:           '0'
            opcode:          alloca
          - index:           '1'
            opcode:          br
      - name:            for.cond
        predecessors:    [ for.cond, entry ]
        successors:      [ for.cond ]
        loops:           [ for.cond ]
        src-hint:        'test.c:18'
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
        successors:      [  ]
        src-hint:        'test.c:30'
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
            opcode:          store
            memmode:         store
          - index:           '4'
            opcode:          store
            memmode:         store
          - index:           '5'
            opcode:          store
            memmode:         store
          - index:           '6'
            opcode:          store
            memmode:         store
          - index:           '7'
            opcode:          call
            intrinsic:       true
          - index:           '8'
            opcode:          load
            memmode:         load
          - index:           '9'
            opcode:          bitcast
          - index:           '10'
            opcode:          call
            callees:         [ __any__ ]
          - index:           '11'
            opcode:          ret
    linkage:         ExternalLinkage
  - name:            test_c_f1
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:9'
        instructions:    
          - index:           '0'
            opcode:          ret
    linkage:         InternalLinkage
  - name:            test_c_f4
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        './test.h:4'
        instructions:    
          - index:           '0'
            opcode:          ret
    linkage:         InternalLinkage
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
      function:        f2
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
      function:        f3
      level:           bitcode
    dst:             
      function:        '3'
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
        src-block:       for.cond
        dst-block:       '1'
        src-successors:  [ '2' ]
        dst-successors:  [ '2' ]
    status:          valid
  - src:             
      function:        c_entry
      level:           bitcode
    dst:             
      function:        '4'
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
      function:        test_c_f1
      level:           bitcode
    dst:             
      function:        '5'
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
      function:        test_c_f4
      level:           bitcode
    dst:             
      function:        '6'
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
        src-hint:        'test.c:4'
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
    mapsto:          f2
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:13'
        instructions:    
          - { index: '0', opcode: t2MOVi16, size: 4 }
          - { index: '1', opcode: t2MOVTi16, size: 4 }
          - { index: '2', opcode: tMOVi8, size: 2 }
          - { index: '3', opcode: tSTRi, size: 2, memmode: store }
          - { index: '4', opcode: tLDRi, size: 2, memmode: load }
          - { index: '5', opcode: tBX_RET, size: 2, branch-type: return }
    linkage:         ExternalLinkage
  - name:            '3'
    level:           machinecode
    mapsto:          f3
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [ '1' ]
        src-hint:        'test.c:18'
        instructions:    
          - { index: '0', opcode: tSUBspi, size: 2 }
          - { index: '1', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '1'
        mapsto:          for.cond
        predecessors:    [ '0', '1' ]
        successors:      [ '1' ]
        loops:           [ '1' ]
        src-hint:        'test.c:18'
        instructions:    
          - { index: '0', opcode: tB, size: 2, branch-type: unconditional }
    linkage:         ExternalLinkage
  - name:            '4'
    level:           machinecode
    mapsto:          c_entry
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:32'
        instructions:    
          - { index: '0', opcode: tPUSH, size: 2, memmode: store }
          - { index: '1', opcode: tMOVr, size: 2 }
          - { index: '2', opcode: tSUBspi, size: 2 }
          - { index: '3', opcode: tMOVr, size: 2 }
          - { index: '4', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '5', opcode: t2MOVi16, size: 4 }
          - { index: '6', opcode: t2MOVTi16, size: 4 }
          - { index: '7', opcode: t2MOVi16, size: 4 }
          - { index: '8', opcode: t2MOVTi16, size: 4 }
          - { index: '9', opcode: tSTRi, size: 2, memmode: store }
          - { index: '10', opcode: t2MOVi16, size: 4 }
          - { index: '11', opcode: t2MOVTi16, size: 4 }
          - { index: '12', opcode: tSTRi, size: 2, memmode: store }
          - { index: '13', opcode: t2MOVi16, size: 4 }
          - { index: '14', opcode: t2MOVTi16, size: 4 }
          - { index: '15', opcode: tSTRi, size: 2, memmode: store }
          - { index: '16', opcode: t2MOVi16, size: 4 }
          - { index: '17', opcode: t2MOVTi16, size: 4 }
          - { index: '18', opcode: tSTRi, size: 2, memmode: store }
          - { index: '19', opcode: tLDRi, size: 2, memmode: load }
          - { index: '20', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '21', opcode: tBLXr, callees: [ __any__ ], size: 2, 
              branch-type: call }
          - { index: '22', opcode: tADDspi, size: 2 }
          - { index: '23', opcode: tPOP_RET, size: 2, branch-type: return }
    linkage:         ExternalLinkage
  - name:            '5'
    level:           machinecode
    mapsto:          test_c_f1
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:9'
        instructions:    
          - { index: '0', opcode: tMOVi8, size: 2 }
          - { index: '1', opcode: tBX_RET, size: 2, branch-type: return }
    linkage:         ExternalLinkage
  - name:            '6'
    level:           machinecode
    mapsto:          test_c_f4
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        './test.h:4'
        instructions:    
          - { index: '0', opcode: tMOVi8, size: 2 }
          - { index: '1', opcode: tBX_RET, size: 2, branch-type: return }
    linkage:         ExternalLinkage
modelfacts:      
  - program-point:   
      function:        '4'
      block:           '0'
      instruction:     '21'
    origin:          platina
    level:           machinecode
    type:            callee
    expression:      '[test.c:f1, f2, test.c:f4]'
...
