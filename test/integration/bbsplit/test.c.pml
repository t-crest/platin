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
  - name:            f
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [ while.body ]
        src-hint:        'test.c:6'
        instructions:    
          - index:           '0'
            opcode:          br
      - name:            while.body
        predecessors:    [ entry, if.end ]
        successors:      [ if.end, if.then ]
        loops:           [ while.body ]
        src-hint:        'test.c:6'
        instructions:    
          - index:           '0'
            opcode:          call
            intrinsic:       true
          - index:           '1'
            opcode:          load
            memmode:         load
          - index:           '2'
            opcode:          icmp
          - index:           '3'
            opcode:          br
      - name:            if.then
        predecessors:    [ while.body ]
        successors:      [ while.end ]
        src-hint:        'test.c:8'
        instructions:    
          - index:           '0'
            opcode:          br
      - name:            if.end
        predecessors:    [ while.body ]
        successors:      [ while.body ]
        loops:           [ while.body ]
        src-hint:        'test.c:6'
        instructions:    
          - index:           '0'
            opcode:          br
      - name:            while.end
        predecessors:    [ if.then ]
        successors:      [  ]
        src-hint:        'test.c:10'
        instructions:    
          - index:           '0'
            opcode:          ret
    linkage:         ExternalLinkage
  - name:            pointed
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:15'
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
            opcode:          load
            memmode:         load
          - index:           '4'
            opcode:          add
          - index:           '5'
            opcode:          ret
    linkage:         ExternalLinkage
  - name:            pointed2
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:19'
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
            opcode:          load
            memmode:         load
          - index:           '4'
            opcode:          sub
          - index:           '5'
            opcode:          ret
    linkage:         ExternalLinkage
  - name:            repointer
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:26'
        instructions:    
          - index:           '0'
            opcode:          store
            memmode:         store
          - index:           '1'
            opcode:          ret
    linkage:         ExternalLinkage
  - name:            g
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [ for.cond ]
        src-hint:        'test.c:29'
        instructions:    
          - index:           '0'
            opcode:          alloca
          - index:           '1'
            opcode:          alloca
          - index:           '2'
            opcode:          call
            intrinsic:       true
          - index:           '3'
            opcode:          store
            memmode:         store
          - index:           '4'
            opcode:          call
            intrinsic:       true
          - index:           '5'
            opcode:          store
            memmode:         store
          - index:           '6'
            opcode:          br
      - name:            for.cond
        predecessors:    [ for.inc, entry ]
        successors:      [ for.body, for.end ]
        loops:           [ for.cond ]
        src-hint:        'test.c:31'
        instructions:    
          - index:           '0'
            opcode:          call
            intrinsic:       true
          - index:           '1'
            opcode:          load
            memmode:         load
          - index:           '2'
            opcode:          icmp
          - index:           '3'
            opcode:          br
      - name:            for.body
        predecessors:    [ for.cond ]
        successors:      [ for.inc ]
        loops:           [ for.cond ]
        src-hint:        'test.c:32'
        instructions:    
          - index:           '0'
            opcode:          call
            callees:         [ f ]
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
      - name:            for.inc
        predecessors:    [ for.body ]
        successors:      [ for.cond ]
        loops:           [ for.cond ]
        src-hint:        'test.c:31'
        instructions:    
          - index:           '0'
            opcode:          load
            memmode:         load
          - index:           '1'
            opcode:          add
          - index:           '2'
            opcode:          store
            memmode:         store
          - index:           '3'
            opcode:          br
      - name:            for.end
        predecessors:    [ for.cond ]
        successors:      [  ]
        src-hint:        'test.c:34'
        instructions:    
          - index:           '0'
            opcode:          call
            callees:         [ f ]
          - index:           '1'
            opcode:          load
            memmode:         load
          - index:           '2'
            opcode:          add
          - index:           '3'
            opcode:          store
            memmode:         store
          - index:           '4'
            opcode:          call
            intrinsic:       true
          - index:           '5'
            opcode:          load
            memmode:         load
          - index:           '6'
            opcode:          load
            memmode:         load
          - index:           '7'
            opcode:          call
            callees:         [ __any__ ]
          - index:           '8'
            opcode:          load
            memmode:         load
          - index:           '9'
            opcode:          add
          - index:           '10'
            opcode:          store
            memmode:         store
          - index:           '11'
            opcode:          load
            memmode:         load
          - index:           '12'
            opcode:          ret
    linkage:         ExternalLinkage
  - name:            h
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:41'
        instructions:    
          - index:           '0'
            opcode:          alloca
          - index:           '1'
            opcode:          call
            intrinsic:       true
          - index:           '2'
            opcode:          call
            callees:         [ f ]
          - index:           '3'
            opcode:          store
            memmode:         store
          - index:           '4'
            opcode:          load
            memmode:         load
          - index:           '5'
            opcode:          add
          - index:           '6'
            opcode:          store
            memmode:         store
          - index:           '7'
            opcode:          load
            memmode:         load
          - index:           '8'
            opcode:          mul
          - index:           '9'
            opcode:          store
            memmode:         store
          - index:           '10'
            opcode:          load
            memmode:         load
          - index:           '11'
            opcode:          ret
    linkage:         ExternalLinkage
  - name:            c_entry
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [ sw.default, sw.bb, sw.bb1, sw.bb3 ]
        src-hint:        'test.c:47'
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
            opcode:          load
            memmode:         load
          - index:           '5'
            opcode:          switch
      - name:            sw.bb
        predecessors:    [ entry ]
        successors:      [ sw.epilog ]
        src-hint:        'test.c:52'
        instructions:    
          - index:           '0'
            opcode:          call
            callees:         [ f ]
          - index:           '1'
            opcode:          store
            memmode:         store
          - index:           '2'
            opcode:          br
      - name:            sw.bb1
        predecessors:    [ entry ]
        successors:      [ sw.epilog ]
        src-hint:        'test.c:55'
        instructions:    
          - index:           '0'
            opcode:          store
            memmode:         store
          - index:           '1'
            opcode:          call
            callees:         [ g ]
          - index:           '2'
            opcode:          store
            memmode:         store
          - index:           '3'
            opcode:          br
      - name:            sw.bb3
        predecessors:    [ entry ]
        successors:      [ sw.epilog ]
        src-hint:        'test.c:59'
        instructions:    
          - index:           '0'
            opcode:          call
            callees:         [ h ]
          - index:           '1'
            opcode:          store
            memmode:         store
          - index:           '2'
            opcode:          br
      - name:            sw.default
        predecessors:    [ entry ]
        successors:      [ sw.epilog ]
        src-hint:        'test.c:62'
        instructions:    
          - index:           '0'
            opcode:          store
            memmode:         store
          - index:           '1'
            opcode:          br
      - name:            sw.epilog
        predecessors:    [ sw.default, sw.bb3, sw.bb1, sw.bb ]
        successors:      [  ]
        src-hint:        'test.c:64'
        instructions:    
          - index:           '0'
            opcode:          load
            memmode:         load
          - index:           '1'
            opcode:          ret
    linkage:         ExternalLinkage
flowfacts:       
  - scope:           
      function:        g
      loop:            for.cond
    lhs:             
      - factor:          1
        program-point:   
          function:        g
          block:           for.cond
    op:              less-equal
    rhs:             '5'
    level:           bitcode
    origin:          user.bc
    classification:  loop-global
modelfacts:      
  - program-point:   
      function:        f
      block:           while.body
    origin:          platina.bc
    level:           bitcode
    type:            lbound
    expression:      '1'
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
      function:        f
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
        src-successors:  [ '3', '4' ]
        dst-successors:  [ '3', '4' ]
      - name:            '3'
        type:            progress
        src-block:       if.end
        dst-block:       '3'
        src-successors:  [ '2' ]
        dst-successors:  [ '2' ]
      - name:            '4'
        type:            progress
        src-block:       if.then
        dst-block:       '2'
        src-successors:  [ '5' ]
        dst-successors:  [ '5' ]
      - name:            '5'
        type:            progress
        src-block:       while.end
        dst-block:       '4'
        src-successors:  [ '1' ]
        dst-successors:  [ '1' ]
    status:          valid
  - src:             
      function:        pointed
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
  - src:             
      function:        pointed2
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
      function:        repointer
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
      function:        g
      level:           bitcode
    dst:             
      function:        '6'
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
        src-successors:  [ '3', '4' ]
        dst-successors:  [ '3', '4' ]
      - name:            '3'
        type:            progress
        src-block:       for.body
        dst-block:       '2'
        src-successors:  [ '5' ]
        dst-successors:  [ '5' ]
      - name:            '4'
        type:            progress
        src-block:       for.end
        dst-block:       '4'
        src-successors:  [ '1' ]
        dst-successors:  [ '1' ]
      - name:            '5'
        type:            progress
        src-block:       for.inc
        dst-block:       '3'
        src-successors:  [ '2' ]
        dst-successors:  [ '2' ]
    status:          valid
  - src:             
      function:        h
      level:           bitcode
    dst:             
      function:        '7'
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
      function:        '8'
      level:           machinecode
    nodes:           
      - name:            '0'
        type:            entry
        src-block:       entry
        dst-block:       '0'
        src-successors:  [ '4', '5', '6', '7' ]
        dst-successors:  [ '2', '4' ]
      - name:            '1'
        type:            exit
      - name:            '2'
        type:            dst
        dst-block:       '1'
        dst-successors:  [ '3', '5' ]
      - name:            '3'
        type:            dst
        dst-block:       '2'
        dst-successors:  [ '6', '7' ]
      - name:            '4'
        type:            progress
        src-block:       sw.bb
        dst-block:       '3'
        src-successors:  [ '8' ]
        dst-successors:  [ '8' ]
      - name:            '5'
        type:            progress
        src-block:       sw.bb1
        dst-block:       '4'
        src-successors:  [ '8' ]
        dst-successors:  [ '8' ]
      - name:            '6'
        type:            progress
        src-block:       sw.bb3
        dst-block:       '5'
        src-successors:  [ '8' ]
        dst-successors:  [ '8' ]
      - name:            '7'
        type:            progress
        src-block:       sw.default
        dst-block:       '6'
        src-successors:  [ '8' ]
        dst-successors:  [ '8' ]
      - name:            '8'
        type:            progress
        src-block:       sw.epilog
        dst-block:       '7'
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
          - { index: '0', opcode: tSUBspi, size: 2 }
          - { index: '1', opcode: tMOVi8, size: 2 }
          - { index: '2', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '3', opcode: tADDspi, size: 2 }
          - { index: '4', opcode: tBX_RET, size: 2, branch-type: return }
    linkage:         ExternalLinkage
  - name:            '2'
    level:           machinecode
    mapsto:          f
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [ '1' ]
        src-hint:        'test.c:6'
        instructions:    
          - { index: '0', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '1'
        mapsto:          while.body
        predecessors:    [ '0', '3' ]
        successors:      [ '3', '2' ]
        loops:           [ '1' ]
        src-hint:        'test.c:8'
        instructions:    
          - { index: '0', opcode: t2MOVi16, size: 4 }
          - { index: '1', opcode: t2MOVTi16, size: 4 }
          - { index: '2', opcode: tLDRi, size: 2, memmode: load }
          - { index: '3', opcode: tCMPi8, size: 2 }
          - { index: '4', opcode: tBcc, size: 2, branch-type: conditional }
          - { index: '5', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '2'
        mapsto:          if.then
        predecessors:    [ '1' ]
        successors:      [ '4' ]
        src-hint:        'test.c:8'
        instructions:    
          - { index: '0', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '3'
        mapsto:          if.end
        predecessors:    [ '1' ]
        successors:      [ '1' ]
        loops:           [ '1' ]
        src-hint:        'test.c:6'
        instructions:    
          - { index: '0', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '4'
        mapsto:          while.end
        predecessors:    [ '2' ]
        successors:      [  ]
        src-hint:        'test.c:10'
        instructions:    
          - { index: '0', opcode: tMOVi8, size: 2 }
          - { index: '1', opcode: tBX_RET, size: 2, branch-type: return }
    linkage:         ExternalLinkage
  - name:            '3'
    level:           machinecode
    mapsto:          pointed
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:16'
        instructions:    
          - { index: '0', opcode: tSUBspi, size: 2 }
          - { index: '1', opcode: tMOVr, size: 2 }
          - { index: '2', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '3', opcode: tLDRspi, size: 2, memmode: load }
          - { index: '4', opcode: tADDi8, size: 2 }
          - { index: '5', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '6', opcode: tADDspi, size: 2 }
          - { index: '7', opcode: tBX_RET, size: 2, branch-type: return }
    linkage:         ExternalLinkage
  - name:            '4'
    level:           machinecode
    mapsto:          pointed2
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:20'
        instructions:    
          - { index: '0', opcode: tSUBspi, size: 2 }
          - { index: '1', opcode: tMOVr, size: 2 }
          - { index: '2', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '3', opcode: tLDRspi, size: 2, memmode: load }
          - { index: '4', opcode: tSUBi8, size: 2 }
          - { index: '5', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '6', opcode: tADDspi, size: 2 }
          - { index: '7', opcode: tBX_RET, size: 2, branch-type: return }
    linkage:         ExternalLinkage
  - name:            '5'
    level:           machinecode
    mapsto:          repointer
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:26'
        instructions:    
          - { index: '0', opcode: t2MOVi16, size: 4 }
          - { index: '1', opcode: t2MOVTi16, size: 4 }
          - { index: '2', opcode: t2MOVi16, size: 4 }
          - { index: '3', opcode: t2MOVTi16, size: 4 }
          - { index: '4', opcode: tSTRi, size: 2, memmode: store }
          - { index: '5', opcode: tBX_RET, size: 2, branch-type: return }
    linkage:         ExternalLinkage
  - name:            '6'
    level:           machinecode
    mapsto:          g
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [ '1' ]
        src-hint:        'test.c:29'
        instructions:    
          - { index: '0', opcode: tPUSH, size: 2, memmode: store }
          - { index: '1', opcode: tMOVr, size: 2 }
          - { index: '2', opcode: tSUBspi, size: 2 }
          - { index: '3', opcode: tMOVi8, size: 2 }
          - { index: '4', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '5', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '6', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '1'
        mapsto:          for.cond
        predecessors:    [ '0', '3' ]
        successors:      [ '2', '4' ]
        loops:           [ '1' ]
        src-hint:        'test.c:31'
        instructions:    
          - { index: '0', opcode: tLDRspi, size: 2, memmode: load }
          - { index: '1', opcode: tCMPi8, size: 2 }
          - { index: '2', opcode: tBcc, size: 2, branch-type: conditional }
          - { index: '3', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '2'
        mapsto:          for.body
        predecessors:    [ '1' ]
        successors:      [ '3' ]
        loops:           [ '1' ]
        src-hint:        'test.c:32'
        instructions:    
          - { index: '0', opcode: tBL, callees: [ f ], size: 4, branch-type: call }
          - { index: '1', opcode: t2LDRi12, size: 4, memmode: load }
          - { index: '2', opcode: tADDhirr, size: 2 }
          - { index: '3', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '4', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '3'
        mapsto:          for.inc
        predecessors:    [ '2' ]
        successors:      [ '1' ]
        loops:           [ '1' ]
        src-hint:        'test.c:31'
        instructions:    
          - { index: '0', opcode: tLDRspi, size: 2, memmode: load }
          - { index: '1', opcode: tADDi8, size: 2 }
          - { index: '2', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '3', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '4'
        mapsto:          for.end
        predecessors:    [ '1' ]
        successors:      [  ]
        src-hint:        'test.c:34'
        instructions:    
          - { index: '0', opcode: tBL, callees: [ f ], size: 4, branch-type: call }
          - { index: '1', opcode: t2LDRi12, size: 4, memmode: load }
          - { index: '2', opcode: tADDhirr, size: 2 }
          - { index: '3', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '4', opcode: t2MOVi16, size: 4 }
          - { index: '5', opcode: t2MOVTi16, size: 4 }
          - { index: '6', opcode: tLDRi, size: 2, memmode: load }
          - { index: '7', opcode: t2LDRi12, size: 4, memmode: load }
          - { index: '8', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '9', opcode: tMOVr, size: 2 }
          - { index: '10', opcode: t2LDRi12, size: 4, memmode: load }
          - { index: '11', opcode: tBLXr, callees: [ __any__ ], size: 2, 
              branch-type: call }
          - { index: '12', opcode: t2LDRi12, size: 4, memmode: load }
          - { index: '13', opcode: tADDhirr, size: 2 }
          - { index: '14', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '15', opcode: tLDRspi, size: 2, memmode: load }
          - { index: '16', opcode: tADDspi, size: 2 }
          - { index: '17', opcode: tPOP_RET, size: 2, branch-type: return }
    linkage:         ExternalLinkage
  - name:            '7'
    level:           machinecode
    mapsto:          h
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:41'
        instructions:    
          - { index: '0', opcode: tPUSH, size: 2, memmode: store }
          - { index: '1', opcode: tMOVr, size: 2 }
          - { index: '2', opcode: tSUBspi, size: 2 }
          - { index: '3', opcode: tBL, callees: [ f ], size: 4, branch-type: call }
          - { index: '4', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '5', opcode: tLDRspi, size: 2, memmode: load }
          - { index: '6', opcode: tADDi8, size: 2 }
          - { index: '7', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '8', opcode: tLDRspi, size: 2, memmode: load }
          - { index: '9', opcode: t2MOVi, size: 4 }
          - { index: '10', opcode: t2MUL, size: 4 }
          - { index: '11', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '12', opcode: tLDRspi, size: 2, memmode: load }
          - { index: '13', opcode: tADDspi, size: 2 }
          - { index: '14', opcode: tPOP_RET, size: 2, branch-type: return }
    linkage:         ExternalLinkage
  - name:            '8'
    level:           machinecode
    mapsto:          c_entry
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [ '3', '1' ]
        src-hint:        'test.c:49'
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
          - { index: '10', opcode: tLDRspi, size: 2, memmode: load }
          - { index: '11', opcode: tCMPi8, size: 2 }
          - { index: '12', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '13', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '14', opcode: tBcc, size: 2, branch-type: conditional }
          - { index: '15', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '1'
        mapsto:          entry
        predecessors:    [ '0' ]
        successors:      [ '4', '2' ]
        src-hint:        'test.c:50'
        instructions:    
          - { index: '0', opcode: tLDRspi, size: 2, memmode: load }
          - { index: '1', opcode: tCMPi8, size: 2 }
          - { index: '2', opcode: tBcc, size: 2, branch-type: conditional }
          - { index: '3', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '2'
        mapsto:          entry
        predecessors:    [ '1' ]
        successors:      [ '5', '6' ]
        src-hint:        'test.c:50'
        instructions:    
          - { index: '0', opcode: tLDRspi, size: 2, memmode: load }
          - { index: '1', opcode: tCMPi8, size: 2 }
          - { index: '2', opcode: tBcc, size: 2, branch-type: conditional }
          - { index: '3', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '3'
        mapsto:          sw.bb
        predecessors:    [ '0' ]
        successors:      [ '7' ]
        src-hint:        'test.c:52'
        instructions:    
          - { index: '0', opcode: tBL, callees: [ f ], size: 4, branch-type: call }
          - { index: '1', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '2', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '4'
        mapsto:          sw.bb1
        predecessors:    [ '1' ]
        successors:      [ '7' ]
        src-hint:        'test.c:55'
        instructions:    
          - { index: '0', opcode: t2MOVi16, size: 4 }
          - { index: '1', opcode: t2MOVTi16, size: 4 }
          - { index: '2', opcode: t2MOVi16, size: 4 }
          - { index: '3', opcode: t2MOVTi16, size: 4 }
          - { index: '4', opcode: tSTRi, size: 2, memmode: store }
          - { index: '5', opcode: tBL, callees: [ g ], size: 4, branch-type: call }
          - { index: '6', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '7', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '5'
        mapsto:          sw.bb3
        predecessors:    [ '2' ]
        successors:      [ '7' ]
        src-hint:        'test.c:59'
        instructions:    
          - { index: '0', opcode: tBL, callees: [ h ], size: 4, branch-type: call }
          - { index: '1', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '2', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '6'
        mapsto:          sw.default
        predecessors:    [ '2' ]
        successors:      [ '7' ]
        src-hint:        'test.c:62'
        instructions:    
          - { index: '0', opcode: tMOVi8, size: 2 }
          - { index: '1', opcode: tSTRspi, size: 2, memmode: store }
          - { index: '2', opcode: tB, size: 2, branch-type: unconditional }
      - name:            '7'
        mapsto:          sw.epilog
        predecessors:    [ '5', '4', '3', '6' ]
        successors:      [  ]
        src-hint:        'test.c:64'
        instructions:    
          - { index: '0', opcode: tLDRspi, size: 2, memmode: load }
          - { index: '1', opcode: tADDspi, size: 2 }
          - { index: '2', opcode: tPOP_RET, size: 2, branch-type: return }
    linkage:         ExternalLinkage
modelfacts:      
  - program-point:   
      function:        '6'
      block:           '4'
      instruction:     '11'
    origin:          platina
    level:           machinecode
    type:            callee
    expression:      '[pointed]'
...
