Paperpile.PluginGridRSS = Ext.extend(Paperpile.PluginGridDB, {

    plugin_base_query:'',
    plugin_iconCls: 'pp-icon-feed',
    plugin_name:'RSS',
    
    initComponent:function() {

        Paperpile.PluginGridRSS.superclass.initComponent.apply(this, arguments);

        this.actions['IMPORT'].show();
        this.actions['NEW'].hide();
        this.actions['EDIT'].hide();
        this.actions['TRASH'].hide();

        this.actions['IMPORT_ALL'].show();
        this.actions['IMPORT_ALL'].enable();

        this.store.on('beforeload',
                      function(){
                          Paperpile.status.showBusy('Parsing file.');
                      }, this);
        
        this.store.on('load',
                      function(){
                          Paperpile.status.clearMsg();
                      }, this);

    },

});