
// BASE METHODS ============================================================

AQ.OperationType.compute_categories = function(ots) {

  ots.categories = aq.uniq(aq.collect(ots,function(ot) {
    return ot.category;
  }));

}

AQ.OperationType.all = function(rest) {

  return this.super('all',rest).then(
    (ots) => {
      this.compute_categories(ots);
      return ots;
    });

}

AQ.OperationType.all_with_content = function() {

  return this.array_query(
      'all', [], 
      { methods: [ 'field_types', 'cost_model', 'documentation' ] }
    ).then((ots) => {
      aq.each(ots,function(ot) { ot.upgrade_field_types(); })
      this.compute_categories(ots);
      return ots;
    });

}

// RECORD METHODS ==================================================

AQ.OperationType.record_methods.upgrade_field_types = function() {
  this.field_types = aq.collect(this.field_types,(ft) => { 
    var upgraded_ft = AQ.FieldType.record(ft);
    if ( ft.allowable_field_types.length > 0 ) {
      upgraded_ft.current_aft_id = ft.allowable_field_types[0].id;
    }
    return upgraded_ft;
  });
}

AQ.OperationType.record_methods.num_inputs = function() {
  return aq.where(this.field_types,(ft) => { return ft.role === 'input' }).length;
}

AQ.OperationType.record_methods.num_outputs = function() {
  return aq.where(this.field_types,(ft) => { return ft.role === 'output' }).length;
}

AQ.OperationType.record_methods.new_operation = function() {
  return new Promise(function(resolve,reject) {
    resolve("New Operation");
  });
}

AQ.OperationType.record_getters.numbers = function() {

  var ot = this;

  delete ot.numbers;
  ot.numbers = {};
  
  AQ.post("/operation_types/numbers",ot).then((response) => {
    ot.numbers = response.data;
  }).catch((response) => {
    console.log(["error", response.data]);
  })

  return {};

}

AQ.OperationType.record_methods.schedule = function(operations) {

  var op_ids = aq.collect(operations,(op) => {
    return op.id;
  });

  return new Promise(function(resolve,reject) {

    AQ.post("/operations/batch", { operation_ids: op_ids }).then(
      response => resolve(response.data.operations),
      response => reject(response.data.operations)
    );

  });

}

AQ.OperationType.record_methods.unschedule = function(operations) {

  var op_ids = aq.collect(operations,(op) => {
    return op.id;
  });

  return new Promise(function(resolve,reject) {

    AQ.post("/operations/unbatch", { operation_ids: op_ids }).then(
      response => resolve(response.data.operations),
      response => reject(response.data.operations)
    );

  });

}

AQ.OperationType.record_methods.code = function(name) {

  var ot = this;

  delete ot[name];
  ot[name]= { content: "Loading " + name, name: "name", no_edit: true };

  AQ.Code.where({parent_class: "OperationType", parent_id: ot.id, name: name}).then(codes => {
    if ( codes.length > 0 ) {
      latest = aq.where(codes,code => { return code.child_id == null });
      if ( latest.length >= 1 ) {
        ot[name] = latest[0];
      } else {
        console.log("no latest");
        ot[name]= { content: "# Add code here.", name: "name" };
      }
    } else { 
      ot[name]= { content: "# Add code here.", name: "name" };
    }
    AQ.update();
  });

  return ot[name];

}

AQ.OperationType.record_getters.protocol = function() {
  return this.code("protocol");
}

AQ.OperationType.record_getters.documentation = function() {
  return this.code("documentation");
}

AQ.OperationType.record_getters.cost_model = function() {
  return this.code("cost_model");
}

AQ.OperationType.record_getters.precondition = function() {
  return this.code("precondition");
}

AQ.OperationType.record_getters.field_types = function() {

  console.log("Field types")
  
  var ot = this;
  delete ot.field_types;
  ot.field_types = [];
  ot.loading_field_types = true;

  AQ.FieldType.where({parent_class: "OperationType", parent_id: ot.id}).then(fts => {
    ot.field_types = fts;
    ot.loading_field_types = false;
    AQ.update();
  });

  return ot.field_types;

}

AQ.OperationType.record_getters.protocol_versions = function() {

  var ot = this;
  delete ot.protocol_versions;
  ot.protocol_versions = [];

  AQ.Code.where({parent_class: "OperationType", parent_id: ot.id, name: 'protocol'}).then(codes => {
    ot.protocol_versions = codes.reverse();
    AQ.update();
  });

  return ot.protocol_versions;

}

AQ.OperationType.record_methods.remove_predecessors = function() {
  // This method can be used to remove references to predecessors in field types
  // so that the resulting object is guaranteed not to be circular
  var ot = this;
  aq.each(ot.field_types,ft => {
    delete ft.predecessors;
  });
  return ot;
}
