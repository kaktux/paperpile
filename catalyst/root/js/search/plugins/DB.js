Paperpile.PluginGridDB = Ext.extend(Paperpile.PluginGrid, {

    plugin_base_query:'',
    plugin_iconCls: 'pp-icon-folder',

    initComponent:function() {

        this.plugin_name='DB';
      
        Paperpile.PluginGridDB.superclass.initComponent.apply(this, arguments);

        var menu = new Ext.menu.Menu({
            defaults: {checked: false,
                       group: 'filter'+this.id,
                       checkHandler: this.toggleFilter,
                       scope:this,
                      },
            items: [ { text: 'All fields',
                       checked: true,
                       itemId: 'all_nopdf',
                     }, 
                     { text: 'All fields + PDF fulltext',
                       itemId: 'all_pdf',
                     }, 
                     '-', 
                     { text: 'Author', itemId: 'author'}, 
                     { text: 'Title',  itemId: 'title' },
                     { text: 'Journal', itemId: 'journal'},
                     { text: 'Abstract', itemId: 'abstract'},
                     { text: 'PDF fulltext', itemId: 'text'},
                     { text: 'Notes', itemId: 'notes'},
                     { text: 'Year', itemId: 'year'},
                   ]
        });

        this.filterField=new Ext.app.FilterField({store: this.store, 
                                                  base_query: this.plugin_base_query,
                                                  width: 320,
                                                 });
        var tbar=this.getTopToolbar();
        tbar.unshift({xtype:'button', text: 'Filter', menu: menu });
        tbar.unshift(this.filterField);

        // If we are viewing a virtual folders we need an additional
        // button to remove an entry from a virtual folder

        if (this.plugin_base_query.match('^folders:')){

            var menu = new Ext.menu.Menu({
                itemId: 'deleteMenu',
                items: [
                    {  text: 'Delete from library',
                       listeners: {
                           click:  {fn: this.deleteEntry, scope: this}
                       },
                    },
                    {  text: 'Delete from folder',
                       listeners: {
                           click:  {fn: this.deleteFromFolder, scope: this}
                       },
                    }
                ]
            });

            tbar[this.getButtonIndex('delete_button')]= {   xtype:'button',
                                                            text: 'Delete',
                                                            itemId: 'delete_button',
                                                            cls: 'x-btn-text-icon delete',
                                                            menu: menu
                                                        };
        }
        
        this.store.baseParams['plugin_search_pdf']= 0 ;

    },

    onRender: function() {
        Paperpile.PluginGridDB.superclass.onRender.apply(this, arguments);
        this.store.load({params:{start:0, limit:25 }});

        this.store.on('load', function(){
            this.getSelectionModel().selectFirstRow();
        }, this, {
            single: true
        });
    },

    toggleFilter: function(item, checked){
        console.log(item.itemId, checked);

        // Toggle 'search_pdf' option 
        if (item.itemId == 'all_pdf'){
            this.store.baseParams['plugin_search_pdf']= checked ? 1:0 ;
        }
        
        // Specific fields
        if (item.itemId != 'all_pdf' && item.itemId != 'all_nopdf'){
            if (checked){
                this.filterField.singleField=item.itemId;
                this.store.baseParams['plugin_search_pdf']= (item.itemId == 'text') ? 1:0;
            } else {
                if (this.filterField.singleField == item.itemId){
                    this.filterField.singleField="";
                }
            }
        }

        if (checked){
            this.filterField.onTrigger2Click();
        }
      
    },

    //
    // Delete entry from virtual folder
    //

    deleteFromFolder: function(){
        
        var rowid=this.getSelectionModel().getSelected().get('_rowid');
        var sha1=this.getSelectionModel().getSelected().data.sha1;

        var match=this.plugin_base_query.match('folders:(.*)$');

        Ext.Ajax.request({
            url: '/ajax/tree/delete_from_folder',
            params: { rowid: rowid,
                      grid_id: this.id,
                      folder_id: match[1]
                    },
            method: 'GET',
            success: function(){
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Entry deleted.');
            },
        });

        this.store.remove(this.store.getAt(this.store.find('sha1',sha1)));

    },




});
