Paperpile.PluginGridGoogleScholar = Ext.extend(Paperpile.PluginGrid, {


    plugin_title: 'GoogleScholar',
    loadMask: {msg:"Searching Google Scholar"},
    plugin_iconCls: 'pp-icon-google',
    limit:10,

    initComponent:function() {

        var _searchField=new Ext.app.SearchField({
            width:320,
        })

        Ext.apply(this, {
            plugin_name: 'GoogleScholar',
            tbar:[_searchField,
                  {xtype:'tbfill'},
                  {   xtype:'button',
                      itemId: 'add_button',
                      text: 'Import',
                      cls: 'x-btn-text-icon add',
                      listeners: {
                          click:  {
                              fn: function(){
                                  this.insertEntry();
                              },
                              scope: this
                          },
                      },
                  },
                 ],
        });

        Paperpile.PluginGridGoogleScholar.superclass.initComponent.apply(this, arguments);

        // hide key field
        this.getColumnModel().setHidden(2,true);

        _searchField.store=this.store;

    },
    
    onRender: function() {
        Paperpile.PluginGridGoogleScholar.superclass.onRender.apply(this, arguments);
        
        if (this.plugin_query != ''){
            this.store.load({params:{start:0, limit:10 }});
        }
    },


});