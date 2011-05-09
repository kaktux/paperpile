Ext.define('Paperpile.pub.panel.Collections', {
  extend: 'Paperpile.pub.PubPanel',
  alias: 'widget.Collections',
  initComponent: function() {
    Ext.apply(this, {});

    this.callParent(arguments);
  },

  viewRequiresUpdate: function() {
    var needsUpdate = this.callParent(arguments);

    Ext.each(this.selection, function(pub) {
      if (pub.modified.labels || pub.modified.folders) {
        needsUpdate = true;
      }
    });
    return needsUpdate;
  },

  getCommonFunctions: function() {
    var me = this;
    return {
      hasFolders: function(data) {
        return this.hasCollection(data, 'folders');
      },
      hasLabels: function(data) {
        return this.hasCollection(data, 'labels');
      },
      hasCollection: function(data, type) {
        var has = false;
        if (data[type] != '') {
          return true;
        }
        Ext.each(data, function(item) {
          if (item[type] != '') {
            has = true;
          }
        });
        return has;
      },
      folderMax: function() {
        return 4;
      },
      labelMax: function() {
        return 8;
      },
      getFoldersList: function() {
        var all = this.getCollectionAsList('folders');
        // Max out at showing 10 collection items.
        var maxCount = this.folderMax();
        if (all.length > maxCount) {
          all = all.slice(0, maxCount - 1);
        }
        return all;
      },
      getLabelsList: function() {
        var all = this.getCollectionAsList('labels');
        // Max out at showing 10 collection items.
        var maxCount = this.labelMax();
        if (all.length > maxCount) {
          all = all.slice(0, maxCount - 1);
        }
        return all;
      },
      getFolderOverflow: function() {
        return this.getOverflow('folders', this.folderMax());
      },
      getLabelOverflow: function() {
        return this.getOverflow('labels', this.labelMax());
      },
      getOverflow: function(type, max) {
        var all = this.getCollectionAsList(type);
        if (all.length > max) {
          return (all.length - max);
        } else {
          return 0;
        }
      },
      getCollectionAsList: function(collectionType) {
        var grid = me.up('pubview').grid;
        return grid.getSelectedCollections(collectionType).getRange();
      }
    };
  },

  createTemplates: function() {
    var me = this;

    me.callParent(arguments);

    me.singleTpl = new Ext.XTemplate(
      '<div class="pp-box pp-box-side-panel pp-box-top pp-box-style1">',
      '<h2>Organize</h2>',
      '<tpl if="this.hasFolders(values)">',
      '<div class="pp-folders-list pp-box pp-box-style1">',
      '  <tpl for="this.getFoldersList()">',
      '    <div style="display:block;">',
      '      <div style="float:right;">',
      '        {[Paperpile.pub.PubPanel.iconButton("REMOVE_FOLDER", values.guid)]}',
      '      </div>',
      '    {[Paperpile.pub.PubPanel.link("OPEN_FOLDER", values.guid, values.name, "pp-folderlink")]}',
      '    </div>',
      '  </tpl>',
      '  <tpl if="this.getFolderOverflow() != 0">',
      '    {[this.getFolderOverflow()]} more...',
      '  </tpl>',
      '      <div style="float:right;">',
      '      {[Paperpile.pub.PubPanel.miniLink("ADD_FOLDER_PANEL", values.guid, "Add/Edit")]}',
      '      </div>',
      '      <div style="clear:both;"></div>',
      '</div>',
      '</tpl>',
      '  <tpl if="!this.hasFolders(values)">',
      '      {[Paperpile.pub.PubPanel.button("ADD_FOLDER_PANEL", values.guid, "Add to Folder")]}',
      '  </tpl>',
      '  <tpl if="this.hasLabels(values)">',
      '<div class="pp-labels-list pp-box pp-box-style1">',
      '  <tpl for="this.getLabelsList()">',
      '    <div class="pp-label-box pp-label-style-{style}">',
      '      <div class="pp-label-name pp-label-style-{style}">{[Paperpile.utils.formatLabelName(values.multiName)]}</div>',
      '      <div class="pp-action pp-label-remove pp-label-style-{style}" action="REMOVE_LABEL" args="{guid}">x</div>',
      '    </div>',
      '  </tpl>',
      '  <div style="clear: both;"></div>',
      '  <tpl if="this.getLabelOverflow() != 0">',
      '    {[this.getLabelOverflow()]} more...',
      '  </tpl>',
      '    <div style="float: right;">',
      '      {[Paperpile.pub.PubPanel.miniLink("ADD_LABEL_PANEL", values.guid, "Add/Edit")]}',
      '    </div>',
      '    <div style="clear: both;"></div>',
      '</div>',
      '  </tpl>',
      '  <tpl if="!this.hasLabels(values)">',
      '      {[Paperpile.pub.PubPanel.button("ADD_LABEL_PANEL", values.guid, "Add Label(s)")]}',
      '  </tpl>',
      '</div>', Ext.apply(this.getCommonFunctions(), {}));

    me.multiTpl = me.singleTpl;
    /*
    me.multiTpl = new Ext.XTemplate(
      '<div class="pp-box pp-box-side-panel pp-box-top pp-box-style1">',
      '<h2>Folders and Labels</h2>',
      '<tpl if="this.hasFolders(values)">',
      '  <dt>Folders: </dt>',
      '  <dd>',
      '    <ul class="pp-folders">',
      '    <tpl for="this.getFoldersList(values)">',
      '      <li class="pp-folder-list pp-folder-generic">',
      '        <a href="#" class="pp-action pp-textlink" action="OPEN_FOLDER" args="{guid}">{multiName}</a> &nbsp;&nbsp;',
      '        <a href="#" class="pp-action pp-textlink pp-second-link" action="REMOVE_FOLDER" args="{guid}">Remove</a>',
      '      </li>',
      '    </tpl>',
      '    </ul>',
      '    <div style="clear:both;"></div>',
      '      <tpl if="this.getFolderOverflow() != 0">',
      '        ({[this.getFolderOverflow()]} more...)',
      '      </tpl>',
      '  </dd>',
      '</tpl>',
      '<tpl if="this.hasLabels(values)">',
      '  <dt>Labels: </dt>',
      '  <dd>',
      '    <div class="pp-labels-div">',
      '      <tpl for="this.getLabelsList(values)">',
      '        <div class="pp-label-box pp-label-style-{style}">',
      '          <div class="pp-label-name pp-label-style-{style}">{multiName}</div>',
      '          <div class="pp-action pp-label-remove pp-label-style-{style}" action="REMOVE_LABEL" args="{guid}">x</div>',
      '        </div>',
      '      </tpl>',
      '    </div>',
      '    <div style="clear:both;"></div>',
      '      <tpl if="this.getLabelOverflow() != 0">',
      '        ({[this.getLabelOverflow()]} more...)',
      '      </tpl>',
      '  </dd>',
      '</tpl>',
      '<div style="clear:left;"></div>',
      '</div>', Ext.apply(this.getCommonFunctions(), {}));
    */
  }
});