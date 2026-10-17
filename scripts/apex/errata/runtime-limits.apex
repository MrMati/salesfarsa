System.debug('LIMITS=' + JSON.serialize(new Map<String,Integer>{
    'SOQL'=>Limits.getLimitQueries(), 'SOSL'=>Limits.getLimitSoslQueries(),
    'rows'=>Limits.getLimitQueryRows(), 'CPU_ms'=>Limits.getLimitCpuTime(),
    'heap_bytes'=>Limits.getLimitHeapSize(), 'DML'=>Limits.getLimitDmlStatements()
}));
