Paperpile.ExportBibfile = Ext.extend(Ext.FormPanel, {

    optionFields:{ 'export_bibout_brackets':['BIBTEX'],
                   'export_latexout':['BIBTEX'],
                   'export_bibout_singledash':['BIBTEX'],
                   'export_bibout_whitespace':['BIBTEX'],
                   'export_bibout_finalcomma':['BIBTEX'],
                   'export_xmlout':['MODS'],
                   'export_modsout_dropkey':['MODS'],
                 },

    fileEndings: { BIBTEX:'bib',
                   MODS:'mods',
                   RIS: 'ris',
                   ENDNOTE: 'enl',
                   WORD2007: 'xml',
                   ISI: 'isi',
                 },


    currentType:'',

    initComponent: function() {
		Ext.apply(this, {
            export_name:'Bibfile',
            url:'/ajax/forms/settings',
            defaultType: 'textfield',
            layout:"column",
            border:false,
            items:[
                {columnWidth: 1.0,
                 layout: 'form',
                 xtype:'panel',
                 border:false,
                 items:[
                     {xtype:'combo',
                      itemId:'file_format',
                      editable:false,
                      emptyText: 'Choose file format',
                      forceSelection:true,
                      triggerAction: 'all',
                      disableKeyFilter: true,
                      hideLabel:true,
                      mode: 'local',
                      store: [['BIBTEX','BibTeX'], 
                              ['MODS', 'MODS'],
                              ['RIS','RIS'],
                              ['ENDNOTE','EndNote'],
                              ['ISI','ISI'],
                              ['WORD2007','Word 2007 XML format']
                             ],
                      hiddenName: 'export_out_format',
                      listeners: {
                          select: {
                              fn: function(combo,record,index){
                                  this.setOptionFields(record.data.value);
                                  
                                  this.items.get('path_button').items.get('button').enable();
                                  
                                  this.currentType=record.data.value;
                                  var defaultFile='export.'+this.fileEndings[this.currentType];

                                  var textfield=this.items.get('path').items.get('textfield');
                                  //textfield.enable();
                                  var currentText=textfield.getValue();
                                  
                                  if (currentText == ''){
                                      textfield.setValue(main.globalSettings.homedir+'/'+defaultFile);
                                  } else {
                                      currentText=currentText.replace(/export.(bib|ris|enl|xml|mods)/,defaultFile);
                                      textfield.setValue(currentText);
                                  }
                              },
                              scope:this,
                          }
                      }
                     },
                 ]
                },
                {columnWidth: 0.7,
                 layout: 'form',
                 itemId: 'path',
                 border:false,
                 xtype:'panel',
                 items:[
                     { xtype: 'textfield',
                       itemId: 'textfield',
                       anchor: "100%",
                       hideLabel: true,
                       name: 'export_out_file',
                     }
                 ]
                },
                {columnWidth: 0.3,
                 layout: 'form',
                 border:false,
                 xtype:'panel',
                 itemId:'path_button',
                 items:[
                     { xtype:'button',
                       text: 'Choose file',
                       disabled:true,
                       itemId: 'button',
                       listeners: {
                           click:  { 
                               fn: function(){

                                   var path=this.items.get('path').items.get('textfield').getValue();

                                   var parts=path.split('/');
                                   var defaultFile=parts[parts.length-1];
                                   var newParts=parts.slice(1,parts.length-1);
                                   newParts.unshift('ROOT');
                                   var root=newParts.join('/');

                                   console.log(root, defaultFile);

                                   var win=new Paperpile.FileChooser({
                                       saveMode: true,
                                       saveDefault: defaultFile,
                                       currentRoot: root,
                                       warnOnExisting:false,
                                       callback:function(button,path){
                                           if (button == 'OK'){
                                               path=path.replace(/^ROOT/,'');
                                               this.items.get('path').items.get('textfield').setValue(path);
                                               console.log(path);
                                           }
                                       },
                                       scope:this
                                   });

                                   win.show();

                               },
                               scope:this
                           }
                       },
                     },
                 ]
                },
                {columnWidth: 1.0,
                 layout: 'form',
                 border:false,
                 itemId: 'options',
                 xtype:'panel',
                 labelWidth: 200,
                 items:[
                     { xtype:'checkbox',
                       fieldLabel: '',
                       boxLabel:'Comma after last item',
                       hideLabel:true,
                       name: 'export_bibout_finalcomma',
                       itemId: 'export_bibout_finalcomma',
                     },
                     { xtype:'checkbox',
                       fieldLabel: '',
                       checked:true,
                       boxLabel:'Pretty formatting and indentation',
                       hideLabel:true,
                       name: 'export_bibout_whitespace',
                       itemId: 'export_bibout_whitespace',
                     },
                     { xtype:'checkbox',
                       checked:true,
                       boxLabel: 'Use single dash - instead of -- in page field',
                       hideLabel:true,
                       name: 'export_bibout_singledash',
                       itemId: 'export_bibout_singledash',
                     },
                     { xtype: 'radiogroup',
                       fieldLabel: 'Encode special characters as',
                       itemId: 'export_latexout',
                       items: [
                           {boxLabel: 'LaTeX', name: 'export_latexout', inputValue: true},
                           {boxLabel: 'Unicode (UTF-8)', name: 'export_latexout', inputValue: false, checked: true},
                       ]
                     },
                     { xtype: 'radiogroup',
                       fieldLabel: 'Enclose fields in ',
                       itemId: 'export_bibout_brackets',
                       items: [
                           {boxLabel: 'Brackets {...}', name: 'export_bibout_brackets', inputValue: true},
                           {boxLabel: 'Quotes "..."', name: 'export_bibout_brackets', inputValue: false, checked: true},
                       ]
                     },
                     { xtype: 'radiogroup',
                       fieldLabel: 'Encode special characters as',
                       itemId: 'export_xmlout',
                       items: [
                           {boxLabel: 'XML entities', name: 'export_utf8out', inputValue: true},
                           {boxLabel: 'Unicode (UTF-8)', name: 'export_utf8out', inputValue: false, checked: true},
                       ]
                     },
                     { xtype:'checkbox',
                       checked:true,
                       boxLabel: 'Include IDs',
                       hideLabel:true,
                       name: 'export_modsout_dropkey',
                       itemId: 'export_modsout_dropkey',
                     },
                 ]
                },
            ]
        });
		
        Paperpile.ExportBibfile.superclass.initComponent.call(this);

        this.on('afterlayout', function(){this.setOptionFields(this.currentType)});
    },

    setOptionFields: function(type){

        for (var field in this.optionFields){
            var item=this.items.get('options').items.get(field);
            if (this.optionFields[field].indexOf(type) !=-1){
                item.getEl().up('div.x-form-item').setDisplayed(true);
            } else {
                item.getEl().up('div.x-form-item').setDisplayed(false);
            }
        }
    }

});

Ext.reg('export-bibfile', Paperpile.ExportBibfile);
