Paperpile.PluginGrid = function(config) {
  Ext.apply(this, config);

  Paperpile.PluginGrid.superclass.constructor.call(this, {});

  this.on('rowcontextmenu', this.onContextClick, this);
};

Ext.extend(Paperpile.PluginGrid, Ext.grid.GridPanel, {

  plugin_query: '',
  region: 'center',
  limit: 25,
  allSelected: false,
  itemId: 'grid',
  aboutPanel: null,
  overviewPanel: null,
  detailsPanel: null,
  tagStyles: {},
  author_shrink_threshold: 255,

  initComponent: function() {
    var _pager = new Ext.PagingToolbar({
      pageSize: this.limit,
      store: this.getStore(),
      displayInfo: true,
      displayMsg: 'Displaying references {0} - {1} of {2}',
      emptyMsg: "No references to display"
    });

    var renderPub = function(value, p, record) {
      record.data._notes_tip = Ext.util.Format.stripTags(record.data.annote);
      record.data._citekey = Ext.util.Format.ellipsis(record.data.citekey, 18);
      record.data._createdPretty = Paperpile.utils.prettyDate(record.data.created);

      if (record.data.doi) {
        var wrapped = record.data.doi;

        if (wrapped.length > 25) {
          wrapped = wrapped.replace(/\//, '/<br>');
        }

        record.data._doiWrapped = wrapped;
      }

      /*
	// Shrink very long author lists.
	record.data._long_authorlist = 0;
	var ad = record.data._authors_display;
	if (record.data._shrink_authors == null)
	  record.data._shrink_authors = 1;
	if (ad != null && ad.length > this.author_shrink_threshold) {
	  record.data._long_authorlist = 1;
	  record.data._authors_display_short = ad.substring(0,this.author_shrink_threshold);
	  record.data._authors_display_short_tail = ad.substring(ad.lastIndexOf(","),ad.length);
	} 
*/
      return this.getPubTemplate().apply(record.data);
    };

    var renderIcons = function(value, p, record) {
      // Can possibly be speeded up with compiling the template.
      record.data._notes_tip = Ext.util.Format.stripTags(record.data.annote);
      record.data._citekey = Ext.util.Format.ellipsis(record.data.citekey, 18);
      record.data._createdPretty = Paperpile.utils.prettyDate(record.data.created);
      if (record.data.last_read) {
        record.data._last_readPretty = 'Last read: ' + Paperpile.utils.prettyDate(record.data.last_read);
      } else {
        record.data._last_readPretty = 'Never read';
      }

      record.data.pdf_path = Paperpile.utils.catPath(Paperpile.main.globalSettings.paper_root, record.data.pdf);
      return this.getIconTemplate().apply(record.data);
    };

    this.actions = {
      'EDIT': new Ext.Action({
        text: 'Edit',
        handler: function() {
          this.handleEdit(false)
        },
        scope: this,
        cls: 'x-btn-text-icon edit',
        icon: '/images/icons/pencil.png',
        itemId: 'edit_button',
        tooltip: 'Edit citation data of the selected reference'
      }),

      'DELETE': new Ext.Action({
        text: 'Delete',
        handler: this.handleDelete,
        scope: this,
        cls: 'x-btn-text-icon',
        itemId: 'delete_button',
        tooltip: 'Move selected references to Trash'
      }),

      'EXPORT': new Ext.Action({
        text: 'Export',
        handler: this.handleExport,
        scope: this,
        itemId: 'export_button'
      }),

      'SELECT_ALL': new Ext.Action({
        text: 'Select all',
        handler: this.selectAll,
        scope: this,
        itemId: 'select_all'
      }),

      'FORMAT': new Ext.Action({
        text: 'Format',
        handler: this.formatEntry,
        scope: this,
        itemId: 'format_button'
      }),

      'SAVE_AS_ACTIVE': new Ext.Action({
        text: 'Save as active view',
        handler: this.handleSaveActive,
        scope: this,
        itemId: 'save_active_button'
      }),

      'VIEW_PDF': new Ext.Action({
        text: 'View PDF',
        handler: this.openPDF,
        scope: this,
        iconCls: 'pp-icon-import-pdf',
        itemId: 'view_pdf'
      }),
      'VIEW_AUTHOR': new Ext.Action({
        text: 'First author',
        handler: this.viewByAuthor,
        scope: this,
        itemId: 'view_author_button'
      }),
      'VIEW_LAST_AUTHOR': new Ext.Action({
        text: 'Last author',
        handler: this.viewByLastAuthor,
        scope: this,
        itemId: 'view_last_author_button'
      }),
      'VIEW_JOURNAL': new Ext.Action({
        text: 'Journal',
        handler: this.viewByJournal,
        scope: this,
        itemId: 'view_journal_button'
      }),
      'VIEW_YEAR': new Ext.Action({
        text: 'Year',
        handler: this.viewByYear,
        scope: this,
        itemId: 'view_year_button'
      }),
      'SEARCH_TB_FILL': new Ext.Toolbar.Fill({
        width: '10px',
        itemId: 'search_tb_fill'
      })
    };

    this.actions['SAVE_MENU'] = new Ext.Button({
      itemId: 'save_menu',
      iconCls: 'pp-icon-save',
      cls: 'x-btn-text-icon',
      menu: {
        items: [{
          text: 'Save as Active View',
          iconCls: 'pp-icon-glasses',
          handler: this.handleSaveActive,
          scope: this
        },
        {
          text: 'Export contents to file',
          iconCls: 'pp-icon-disk',
          handler: this.handleExport,
          scope: this
        }]
      }
    });

    var tbar = [
      this.actions['SEARCH_TB_FILL'],
      this.actions['SAVE_MENU']];

    Ext.apply(this, {
      ddGroup: 'gridDD',
      enableDragDrop: true,
      appendOnly: true,
      itemId: 'grid',
      store: this.getStore(),
      bbar: _pager,
      tbar: new Ext.Toolbar({
        itemId: 'toolbar'
      }),
      enableHdMenu: false,
      autoExpandColumn: 'publication',

      columns: [{
        header: "",
        id: 'icons',
        dataIndex: 'title',
        renderer: renderIcons.createDelegate(this),
        width: 50,
        sortable: false,
        resizable: false
      },
      {
        header: "",
        id: 'publication',
        dataIndex: 'title',
        renderer: renderPub.createDelegate(this),
        resizable: false,
        sortable: false,
        scope: this
      }]
    });

    Paperpile.PluginGrid.superclass.initComponent.call(this);

    this.on({
      // Delegate to class methods.
      beforerender: {
        scope: this,
        fn: this.myBeforeRender
      },
      afterrender: {
        scope: this,
        fn: this.myAfterRender
      },
      beforedestroy: {
        scope: this,
        fn: this.onClose
      },
      rowdblclick: {
        scope: this,
        fn: this.onDblClick
      },
      nodedragover: {
        scope: this,
        fn: this.onNodeDrag
      }
    });

    this.store.on({
      loadexception: {
        scope: this,
        fn: function(exception, options, response, error) {
          Paperpile.main.onError(response);
        }
      },
      load: {
        scope: this,
        fn: this.onStoreLoad
      }
    });
  },

  onNodeOver: function(nodeData, source, e, data) {
    if (data.grid) {
      e.cancel = true;
    } else if (data.node) {
      e.cancel = false;
    }

    var retVal = '';
    if (e.cancel) {
      retVal = Ext.dd.DropZone.prototype.dropNotAllowed;
    } else {
      retVal = Ext.dd.DropZone.prototype.dropAllowed;
    }

    this.updateDragStatus(nodeData, source, e, data);
    return retVal;
  },

  updateDragStatus: function(nodeData, source, e, data) {
    var proxy = source.proxy;
    Paperpile.log(source);
    if (source.dragData.node) {
      var myType = source.dragData.node.type;
      if (myType == 'TAGS') {
        proxy.updateTip('Apply label to reference');
      } else if (myType == 'FOLDER') {
        proxy.updateTip('Place reference in folder');
      }
    } else if (source.dragData.grid) {
      // We should never reach here -- no within-grid drag and drop!
    }
  },

  onNodeDrop: function(target, dd, e, data) {
    if (data.node != null) {
      // Get the index of the node being dropped upon.
      var r = e.getTarget(this.getView().rowSelector);
      var index = this.getView().findRowIndex(r);
      var record = this.store.getAt(index);
      // If this node is *outside* the *selection*, then drop on the node instead of
      // the whole selection.
      var sel = this.getSelection();
      if (!this.getSelectionModel().isSelected(index)) {
        sel = record.get('sha1');
      }

      var tagName = data.node.text;

      if (data.node.type) {
        var type = data.node.type;
        if (type == 'FOLDER') {
          Paperpile.main.tree.addFolder(this, sel, data.node);
        } else if (type == 'TAGS') {
          Paperpile.main.tree.addTag(this, sel, data.node);
        }
      }
      return true;

      record.data.pdf_path = Paperpile.utils.catPath(Paperpile.main.globalSettings.paper_root, record.data.pdf);
      return this.getIconTemplate().apply(record.data);
    }
    return false;
  },

  onStoreLoad: function() {
    var container = this.getPluginPanel();
    var ep = container.items.get('east_panel');
    var tb_side = ep.getBottomToolbar();
    var activeTab = ep.getLayout().activeItem.itemId;
    if (this.store.getCount() > 0) {
      if (activeTab === 'about') {
        ep.getLayout().setActiveItem('overview');
        activeTab = 'overview';
      }
    } else {
      container.onEmpty('');
      if (this.sidePanel) {
        ep.getLayout().setActiveItem('about');
        activeTab = 'about';
      }
    }
    tb_side.items.get(activeTab + '_tab_button').toggle(true);

    // If nothing is selected, select first row
    if (!this.getSelectionModel().getSelected()) {
      this.getSelectionModel().selectRow(0);
    };

    container.updateDetails();
    container.updateButtons();
    this.updateButtons();

    //      this.highlightNewArticles();
  },

  highlightNewArticles: function() {
    if (!this.highlightedArticles) {
      this.highlightedArticles = [];
    }

    var s = this.getStore();
    var v = this.getView();
    for (var i = 0; i < s.getCount(); i++) {
      var record = s.getAt(i);
      var el = v.getRow(i);
      if (record.data.created) {
        var secondsAgo = Paperpile.utils.secondsAgo(record.data.created);
        if (secondsAgo < 20) {
          if (!this.highlightedArticles[record.data.sha1]) {
            this.highlightedArticles[record.data.sha1] = 1;
            Ext.get(el).highlight("ffff9c", {
              duration: 3,
              easing: 'easeOut'
            });
          }
        }
      }
    }
  },

  myBeforeRender: function(ct) {
    this.createToolbarMenu();
    this.createContextMenu();
  },

  myAfterRender: function(ct) {
    this.updateButtons();

    // Note: the 'afterselectionchange' event is a custom event, defined in 
    // main/overrides.js
    this.getSelectionModel().on('afterselectionchange',
      function(sm) {
        var selection = this.getSelection();
        var selectedIds;
        if (selection == 'ALL') {
          selectedIds = selection;
        } else {
          selectedIds = selection.join("");
        }
        if (selectedIds == this.lastSelectedIds) {
          return;
        }
        this.lastSelectedIds = selectedIds;

        this.updateButtons();
        this.getPluginPanel().updateDetails();
        this.completeEntry();
      },
      this);

    var map = new Ext.KeyMap(this.body, {
      key: Ext.EventObject.DELETE,
      handler: function() {
        var imported = this.getSelection('IMPORTED').length;
        if (imported > 0) {
          // Handle both cases of normal grids and Trash grid
          if (this.getSelectionModel().getSelected().get('trashed')) {
            this.deleteEntry('DELETE');
          } else {
            this.deleteEntry('TRASH');
          }
        }
      },
      scope: this
    });

    this.dropZone = new Paperpile.GridDropZone(this, {
      ddGroup: this.ddGroup
    });

    Paperpile.GridDragZone = Ext.extend(Ext.grid.GridDragZone, {
      proxy: new Paperpile.StatusTipProxy()
    });
    this.dragZone = new Paperpile.GridDragZone(this, {
      ddGroup: this.ddGroup
    });
  },

  getDragDropText: function() {
    var num = this.getSelectionModel().getCount();
    if (this.allSelected) {
      num = this.getStore().getTotalCount();
    }

    if (num == 1) {
      var key = this.getSelectionModel().getSelected().get('citekey');
      if (key) {
        return "[" + key + "]";
      } else {
        return " 1 selected reference";
      }
    } else {
      return num + " selected references";
    }
  },

  getStore: function() {
    if (this._store != null) {
      return this._store;
    }
    this._store = new Ext.data.Store({
      proxy: new Ext.data.HttpProxy({
        url: Paperpile.Url('/ajax/plugins/resultsgrid'),
        timeout: 10000000,
        // Think about this, different plugins need different timeouts...
        method: 'GET'
      }),
      baseParams: {
        grid_id: this.id,
        plugin_file: this.plugin_file,
        plugin_name: this.plugin_name,
        plugin_query: this.plugin_query,
        plugin_mode: this.plugin_mode,
        plugin_order: "created DESC",
        limit: this.limit
      },
      reader: new Ext.data.JsonReader()
    });
    return this._store;
  },

  gridTemplates: {},

  getPubTemplate: function() {
    if (this.pubTemplate == null) {
      this.pubTemplate = new Ext.XTemplate(
        '<div class="pp-grid-data" sha1="{sha1}">',
        '<div>',
        '<span class="pp-grid-title {_highlight}">{title}</span>{[this.tagStyle(values.tags)]}',
        '</div>',
        '<tpl if="_authors_display">',
        '<p class="pp-grid-authors">{_authors_display}</p>',
        '</tpl>',
        '<tpl if="_citation_display">',
        '<p class="pp-grid-citation">{_citation_display}</p>',
        '</tpl>',
        '<tpl if="_snippets_text">',
        '<p class="pp-grid-snippets"><span class="heading">PDF:</span> {_snippets_text}</p>',
        '</tpl>',
        '<tpl if="_snippets_abstract">',
        '<p class="pp-grid-snippets"><span class="heading">Abstract:</span> {_snippets_abstract}</p>',
        '</tpl>',
        '<tpl if="_snippets_notes">',
        '<p class="pp-grid-snippets"><span class="heading">Notes:</span> {_snippets_notes}</p>',
        '</tpl>',
        '</div>', {
          tagStyle: function(tag_string) {
            var returnMe = ''; //<div class="pp-tag-grid-block">';
            var tags = tag_string.split(/\s*,\s*/);
            var totalChars = 0;
            for (var i = 0; i < tags.length; i++) {
              var tag = tags[i];
              var style = Paperpile.main.tagStore.getAt(Paperpile.main.tagStore.findExact('tag', tag));
              if (style != null) {
                style = style.get('style');
                totalChars += tag.length;
                returnMe += '<div class="pp-tag-grid-inline pp-tag-style-' + style + '">' + tag + '&nbsp;</div>&nbsp;';
              }
            }
            if (tags.length > 0) returnMe = "&nbsp;&nbsp;&nbsp;" + returnMe;
            return returnMe;
          }
        }).compile();
    }

    return this.pubTemplate;
  },

  getIconTemplate: function() {
    if (this.iconTemplate != null) {
      return this.iconTemplate;
    }
    this.iconTemplate = new Ext.XTemplate(
      '<div class="pp-grid-info">',
      '<tpl if="_imported">',
      '  <tpl if="trashed==0">',
      '    <div class="pp-grid-status pp-grid-status-imported" ext:qtip="[<b>{_citekey}</b>]<br>added {_createdPretty}"></div>',
      '  </tpl>',
      '  <tpl if="trashed==1">',
      '    <div class="pp-grid-status pp-grid-status-deleted" ext:qtip="[<b>{_citekey}</b>]<br>deleted {_createdPretty}"></div>',
      '  </tpl>',
      '</tpl>',
      '<tpl if="pdf">',
      '  <div class="pp-grid-status pp-grid-status-pdf" ext:qtip="<b>{pdf}</b><br/>{_last_readPretty}"></div>',
      '</tpl>',
      '<tpl if="attachments">',
      '  <div class="pp-grid-status pp-grid-status-attachments" ext:qtip="{attachments} attached file(s)"></div>',
      '</tpl>',
      '<tpl if="annote">',
      '  <div class="pp-grid-status pp-grid-status-notes" ext:qtip="{_notes_tip}"></div>',
      '</tpl>',
      '</div>').compile();
    return this.iconTemplate;
  },

  getSidebarTemplate: function() {
    if (this.sidebarTemplate == null) {
      this.sidebarTemplate = {
        singleSelection: new Ext.XTemplate(this.getSingleSelectionTemplate()).compile(),
        multipleSelection: new Ext.XTemplate(this.getMultipleSelectionTemplate()).compile()
      };
    }
    return this.sidebarTemplate;
  },

  getSingleSelectionTemplate: function() {
    var prefix = [
      '<div id="main-container-{id}">'];
    var suffix = [
      '</div>'];
    var referenceInfo = [
      '<div class="pp-box pp-box-side-panel pp-box-top pp-box-style1">',
      '<tpl if="_imported">',
      '  <div id="ref-actions" style="float:right;">',
      '  <img src="/images/icons/pencil.png" class="pp-img-action" action="edit-ref" ext:qtip="Edit Reference"/>',
      '  <tpl if="trashed==1">',
      '    <img src="/images/icons/delete.png" class="pp-img-action" action="delete-ref" ext:qtip="Permanently Delete Reference"/>',
      '  </tpl>',
      '  <tpl if="trashed==0">',
      '    <img src="/images/icons/trash.png" class="pp-img-action" action="delete-ref" ext:qtip="Move Reference to Trash"/>',
      '  </tpl>',
      '  </div>',
      '</tpl>',
      '<h2>Reference Info</h2>',
      '<dl>',
      '<tpl if="_pubtype_name">',
      '  <dt>Type: </dt><dd>{_pubtype_name}</dd>',
      '</tpl>',
      '<tpl if="_imported">',
      '  <tpl if="trashed==0">',
      '    <dt>Added: </dt>',
      '  </tpl>',
      '  <tpl if="trashed==1">',
      '    <dt>Deleted: </dt>',
      '  </tpl>',
      '  <dd>{_createdPretty}</dd>',
      '</tpl>',
      '<tpl if="doi">',
      '  <dt>DOI: </dt><dd>{_doiWrapped}</dd>',
      '</tpl>',
      '<tpl if="eprint">',
      '  <dt>Eprint: </dt>',
      '  <dd>{eprint}</dd>',
      '</tpl>',
      '<tpl if="pmid">',
      '  <dt>PubMed ID: </dt><dd>{pmid}</dd>',
      '</tpl>',
      '<tpl if="folders">',
      '  <dt>Folders: </dt>',
      '  <dd>',
      '    <ul class="pp-folders">',
      '    <tpl for="_folders_list">',
      '      <li class="pp-folder-list pp-folder-generic">',
      '        <a href="#" class="pp-textlink" action="open-folder" folder_id="{folder_id}" >{folder_name}</a> &nbsp;&nbsp;',
      '        <a href="#" class="pp-textlink pp-second-link" action="delete-folder" folder_id="{folder_id}" rowid="{rowid}">Remove</a>',
      '      </li>',
      '    </tpl>',
      '    </ul>',
      '  </dd>',
      '</tpl>',
      '<tpl if="_imported">', // Don't show the labels widget if this article isn't imported.
      '  <dt>Labels: </dt>',
      '  <dd>',
      '  <div id="label-widget-{id}" class="pp-label-widget"></div>',
      '  </dd>',
      '</tpl>',
      '</dl>',
      '  <div style="clear:left;"></div>',
      '</div>'];

    var linkOuts = [
      '<tpl if="trashed==0">',
      '  <tpl if="linkout || doi">',
      '    <div class="pp-box pp-box-side-panel pp-box-bottom pp-box-style1">',
      '    <tpl if="doi">',
      '      <p><a href="http://dx.doi.org/{doi}" target="_blank" class="pp-textlink pp-action pp-action-go">Go to Publisher\'s site</a></p>',
      '    </tpl>',
      '    <tpl if="!doi && linkout">',
      '      <p><a href="{linkout}" target="_blank" class="pp-textlink pp-action pp-action-go">Go to Publisher\'s site</a></p>',
      '    </tpl>',
      '    </div>',
      '  </tpl>',
      '  <tpl if="pdf || _imported || linkout || doi">',
      '    <div class="pp-box pp-box-side-panel pp-box-style2"',
      '    <h2>PDF</h2>',
      '        <div id="search-download-widget-{id}" class="pp-search-download-widget"></div>',
      '    <tpl if="_imported">',
      '      <h2>Supplementary material</h2>',
      '      <tpl if="attachments">',
      '        <tpl if="_attachments_list">',
      '          <ul class="pp-attachments">',
      '          <tpl for="_attachments_list">',
      '            <li class="pp-attachment-list pp-file-generic {cls}">',
      '            <a href="#" class="pp-textlink" action="open-attachment" path="{path}">{file}</a>&nbsp;&nbsp;',
      '            <a href="#" class="pp-textlink pp-second-link" action="delete-file" rowid="{rowid}">Delete</a></li>',
      '          </tpl>',
      '          </ul>',
      '        </tpl>',
      '      </tpl>',
      '      <ul>',
      '      <li id="attach-file-{id}" class="pp-action pp-action-attach-file"><a href="#" class="pp-textlink" action="attach-file">Attach File</a></li>', '</ul>',
      '    </tpl>',
      '    </div>',
      '  </tpl>',
      '  </div>',
      '</tpl>'];
    return[].concat(prefix, referenceInfo, linkOuts, suffix);
  },

  getMultipleSelectionTemplate: function() {

    var template = [
      '<div id="main-container-{id}">',
      '  <div class="pp-box pp-box-side-panel pp-box-top pp-box-style1">',
      '  <tpl if="numSelected==0">',
      '  <p>No references in here.</p>',
      '  </tpl>',
      '  <tpl if="numSelected &gt;0">',
      '    <p><b>{numSelected}</b> references selected.</p>',
      '    <div class="pp-vspace"></div>',
      '    <ul> ',
      '      <li class="pp-action pp-action-search-pdf"> <a  href="#" class="pp-textlink" action="batch-download">Download PDFs</a> </li>',
      '      <li class="pp-action pp-action-trash"> <a  href="#" class="pp-textlink" action="delete-ref">Move to Trash</a> </li>',
      '    </ul>',
      '  </tpl>',
      '  </div>',
      '</div>'];
    return[].concat(template);
  },

  createToolbarMenu: function() {
    var tbar = this.getTopToolbar();
    tbar.removeAll();

    tbar.insert(0, new Ext.Button(this.actions['SAVE_MENU']));
    tbar.insert(0, this.actions['SEARCH_TB_FILL']);
  },

  getContextMenu: function() {
    return this.context;
  },

  createContextMenu: function() {
    this.context = new Ext.menu.Menu({
      id: 'pp-grid-context-' + this.id,
      itemId: 'context'
    });
    var context = this.context;
    context.addMenuItem(this.actions['VIEW_PDF']);
    context.addSeparator();
    context.addMenuItem(this.actions['EDIT']);
    context.addMenuItem(this.actions['DELETE']);
    context.addMenuItem(this.actions['SELECT_ALL']);
    context.addSeparator();
    context.addMenuItem({
      text: 'Search by...',
      itemId: 'search_by',
      menu: {
        items: [
          this.actions['VIEW_AUTHOR'],
          this.actions['VIEW_LAST_AUTHOR'],
          this.actions['VIEW_JOURNAL'],
          this.actions['VIEW_YEAR']]
      }
    });
  },

  onContextClick: function(grid, index, e) {
    e.stopEvent();
    var record = this.store.getAt(index);

    if (!this.getSelectionModel().isSelected(index)) {
      this.getSelectionModel().selectRow(index);
    }

    this.context.items.each(function(item, index, length) {
      item.enable();
      this.updateContextItem(item, record);
    },
    this);

    (function() {
      this.context.showAt(e.getXY());
      this.updateButtons();
    }).defer(20, this);
  },

  updateContextItem: function(menuItem, record) {
    // Override with extending classes to update context items on each showing.
    if (menuItem.itemId == this.actions['VIEW_PDF'].itemId && record.data.pdf == '') {
      // Gray out if no PDF available to view.
      menuItem.disable();
      return;
    }

    if (menuItem.itemId == this.actions['SELECT_ALL'].itemId && this.allSelected) {
      // Gray out if already all selected.
      menuItem.disable();
      return;
    }
    return;
  },

  // Private. Don't override.
  updateButtons: function() {
    var tbar = this.getTopToolbar();
    tbar.items.each(function(item, index, length) {
      item.enable();
      this.updateToolbarItem(item);
    },
    this);
  },

  updateToolbarItem: function(menuItem) {
    // Override with extending classes to update toolbar when the grid selection changes.
    if (menuItem.itemId == this.actions['SELECT_ALL'].itemId && this.allSelected) {
      menuItem.disable();
      return;
    }
    return;
  },

  getToolbarByItemId: function(itemId) {
    var tbar = this.getTopToolbar();
    return tbar.items.itemAt(this.getButtonIndex(itemId));
  },

  getContextByItemId: function(itemId) {
    return this.getContextMenu().items.itemAt(this.getContextIndex(itemId));
  },

  // Small helper functions to get the index of a given item in the toolbar configuration array
  // We have to use the text instead of itemId. Actions do not seem to support itemIds.
  // A better solution should be possible with ExtJS 3
  getContextIndex: function(itemId) {
    var context = this.getContextMenu();
    for (var i = 0; i < context.items.length; i++) {
      var item = context.items.itemAt(i);
      if (item.itemId == itemId) return i;
    }
    return -1;
  },

  getTopToolbar: function() {
    var tbar = Paperpile.PluginGrid.superclass.getTopToolbar.call(this);
    if (tbar == null) {
      tbar = this._tbar;
    }
    return tbar;
  },

  getButtonIndex: function(itemId) {
    var tbar = this.getTopToolbar();
    for (var i = 0; i < tbar.items.length; i++) {
      var item = tbar.items.itemAt(i);
      if (item.itemId == itemId) return i;
    }
    return -1;
  },

  getPluginPanel: function() {
    return this.findParentByType(Paperpile.PluginPanel);
  },

  // Returns list of sha1s for the selected entries, either ALL, IMPORTED, NOT_IMPORTED
  getSelection: function(what) {
    if (!what) what = 'ALL';
    if (this.allSelected) {
      return 'ALL';
    }
    var selection = [];
    this.getSelectionModel().each(
      function(record) {
        if ((what == 'ALL') || (what == 'IMPORTED' && record.get('_imported')) || (what == 'NOT_IMPORTED' && !record.get('_imported'))) {
          selection.push(record.get('sha1'));
        }
      });
    return selection;
  },

  // Some plugins use a two-stage process for showing entries: First
  // only minimal info is scraped from site to build list quickly
  // without harassing the site too much. Then the details are
  // fetched only when user clicks the entry.
  completeEntry: function(callback, scope) {
    var sel = this.getSelectionModel().getSelected();
    if (!sel) return;
    var data = sel.data;
    // _details_link indicates if an entry still needs to be completed or not
    if (data._details_link) {
      Paperpile.status.showBusy('Looking up bibliographic data');
      var sha1 = this.getSelectionModel().getSelected().data.sha1;
      Ext.Ajax.request({
        url: Paperpile.Url('/ajax/crud/complete_entry'),
        params: {
          sha1: sha1,
          grid_id: this.id,
        },
        method: 'GET',
        success: function(response) {
          var json = Ext.util.JSON.decode(response.responseText);
          var record = this.store.getAt(this.store.find('sha1', sha1));
          record.beginEdit();
          for (var i in json.data) {
            record.set(i, json.data[i]);
          }
          record.endEdit();

          this.getPluginPanel().updateDetails();

          Paperpile.status.clearMsg();

          if (callback) callback.createDelegate(scope)();
        },
        failure: Paperpile.main.onError,
        scope: this
      });
    } else {
      if (callback) callback.createDelegate(scope)();
    }

  },

  updateDetail: function() {
    // Override with other plugin methods to do things necessary on detail update.
  },

  // If trash is set entries are moved to trash, otherwise they are
  // deleted completely
  // mode: TRASH ... move to trash
  //       RESTORE ... restore from trash
  //       DELETE ... delete permanently
  handleDelete: function() {
    this.deleteEntry('TRASH');
  },

  handleSaveActive: function() {
    Paperpile.main.tree.newActive();
  },

  handleExport: function() {
    selection = this.getSelection();
    var window = new Paperpile.ExportWindow({
      grid_id: this.id,
      selection: selection,
    });
    window.show();
  },

  deleteEntry: function(mode) {
    selection = this.getSelection();
    var index = this.store.indexOf(this.getSelectionModel().getSelected());
    var many = false;

    if (mode == 'DELETE') {
      Paperpile.status.showBusy('Deleting references from library');
    }
    if (mode == 'TRASH') {
      Paperpile.status.showBusy('Moving references to Trash');
    }

    if (mode == 'RESTORE') {
      Paperpile.status.showBusy('Restoring references');
    }

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/delete_entry'),
      params: {
        selection: selection,
        grid_id: this.id,
        mode: mode
      },
      method: 'GET',
      timeout: 10000000,
      success: function(response) {
        var data = Ext.util.JSON.decode(response.responseText);
        var num_deleted = data.num_deleted;

        Paperpile.main.onUpdate(data.data);

        if (mode == 'TRASH') {
          var msg = num_deleted + ' references moved to Trash';
          if (num_deleted == 1) {
            msg = "1 reference moved to Trash";
          }

          Paperpile.status.updateMsg({
            msg: msg,
            action1: 'Undo',
            callback: function(action) {
              // TODO: does not show up, don't know why:
              Paperpile.status.showBusy('Undo...');
              Ext.Ajax.request({
                url: Paperpile.Url('/ajax/crud/undo_trash'),
                method: 'GET',
                success: function(response) {
                  var json = Ext.util.JSON.decode(response.responseText);
                  Paperpile.main.onUpdate(json.data);
                  Paperpile.status.clearMsg();
                },
                scope: this
              });
            },
            scope: this,
            hideOnClick: true
          });
        } else {
          Paperpile.status.clearMsg();
        }
      },
      failure: Paperpile.main.onError,
      scope: this
    });

  },

  handleEdit: function(isNew) {

    var selection = this.getSelectionModel().getSelected();

    if (selection) {
      var rowid = selection.get('_rowid');
      var sha1 = selection.data.sha1;
    }

    win = new Ext.Window({
      title: isNew ? 'Add new reference' : 'Edit reference',
      modal: true,
      shadow: false,
      layout: 'fit',
      width: 800,
      height: 600,
      resizable: false,
      closable: true,
      items: [new Paperpile.MetaPanel({
        data: isNew ? {
          pubtype: 'ARTICLE'
        } : this.getSelectionModel().getSelected().data,
        grid_id: isNew ? null : this.id,
        callback: function(status, data) {
          if (status == 'SAVE') {
            Paperpile.main.onUpdate(data);
            /*
            if (isNew) {
              this.store.reload();
            } else {
              this.updateData(data);
              this.findParentByType(Paperpile.PubView).onRowSelect();
            }
            */
            Paperpile.status.clearMsg();
          }
          win.close();
        },
        scope: this
      })],
    });

    win.show(this);
  },

  batchDownload: function() {
    selection = this.getSelection();
    Ext.getCmp('queue-widget').onUpdate({
      submitting: true
    });
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/batch_download'),
      params: {
        selection: selection,
        grid_id: this.id
      },
      method: 'GET',
      timeout: 10000000,
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        Paperpile.main.onUpdate(json.data);
        // Trigger a thread to start requesting queue updates.
        Paperpile.main.queueUpdate();
      },
      failure: Paperpile.main.onError,
    });
  },

  cancelDownload: function() {
    var selected_id = this.getSelectionModel().getSelected().data._search_job.id;
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/queue/cancel_jobs'),
      params: {
        ids: selected_id
      },
      method: 'GET',
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        Paperpile.main.onUpdate(json.data);
      },
      failure: Paperpile.main.onError
    });
  },

  retryDownload: function() {
    var selected_id = this.getSelectionModel().getSelected().data._search_job.id;
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/queue/retry_jobs'),
      params: {
        ids: selected_id
      },
      method: 'GET',
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        Paperpile.main.onUpdate(json.data);
        Paperpile.main.queueJobUpdate();
      },
      failure: Paperpile.main.onError,
    });

    // TODO: Do a more immediate update to the record so we don't have a delay there.
  },

  clearDownload: function() {
    var selected_id = this.getSelectionModel().getSelected().data._search_job.id;
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/queue/remove_jobs'),
      params: {
        ids: selected_id
      },
      method: 'GET',
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        Paperpile.main.onUpdate(json.data);
      },
      failure: Paperpile.main.onError,
    });

    // TODO: Do a more immediate update to the record so we don't have a delay there.
  },

  formatEntry: function() {

    selection = this.getSelection();

    Paperpile.main.tabs.add(new Paperpile.Format({
      grid_id: this.id,
      selection: selection,
    }));
  },

  // Update specific fields of specific entries to avoid complete
  // reload of everything.
  onUpdate: function(data) {

    var pubs = data.pubs;
    if (!pubs) {
      return;
    }

    var selected_sha1 = '';
    var sel = this.getSelectionModel().getSelected();
    if (sel) selected_sha1 = sel.data.sha1;

    var updateSidePanel = false;
    for (var sha1 in pubs) {
      var record = this.store.getAt(this.store.findExact('sha1', sha1));
      if (!record) {
        continue;
      }
      var needsUpdating = false;
      var update = pubs[sha1];
      record.editing = true; // Set the 'editing' flag.
      for (var field in update) {
        record.set(field, update[field]);
      }
      // Unset the 'editing' flag. Using the flag directly avoids calling store.afterEdit() for every record.
      record.editing = false;
      if (record.dirty) {
        needsUpdating = true;
        if (sha1 == selected_sha1) updateSidePanel = true;
      }
      if (needsUpdating) {
        this.store.fireEvent('update', this.store, record, Ext.data.Record.EDIT);
      }
    }

    if (data.updateSidePanel) updateSidePanel = true;
    if (updateSidePanel) {
      var overview = this.getPluginPanel().getOverview();
      overview.onUpdate(data);
    }
  },

  selectAll: function() {
    this.allSelected = true;
    this.getSelectionModel().selectAll();
    this.getSelectionModel().on('selectionchange',
      function(sm) {
        this.allSelected = false;
      },
      this, {
        single: true
      });
    this.getSelectionModel().on('rowdeselect',
      function(sm) {
        sm.clearSelections();
      },
      this, {
        single: true
      });

  },

  setSearchQuery: function() {
    // To be implemented by subclasses.
  },

  viewByLastAuthor: function() {
    this.viewByAuthor(true);
  },

  viewByAuthor: function(last) {
    last = last || false;
    var sm = this.getSelectionModel();

    var authors = sm.getSelected().data.authors;
    var arr = authors.split(/\s+and\s+/, 2);
    if (arr.length > 1) {
      var first_author = arr[0];
      this.setSearchQuery('author:' + '"' + first_author + '"');
      /*
 	Paperpile.main.tabs.newPluginTab('DB',
					 {plugin_mode:'FULLTEXT',
					 plugin_query:'author:'+'"'+first_author+'"'},
					 first_author,
					 '',
					 first_author
					);
*/
    }
  },
  viewByYear: function() {
    var sm = this.getSelectionModel();
    var year = sm.getSelected().data.year;
    if (year) {
      this.setSearchQuery('year:' + '"' + year + '"');
      /*	Paperpile.main.tabs.newPluginTab('DB',
					 {plugin_mode:'FULLTEXT',
					 plugin_query:'year:'+'"'+year+'"'},
					 year,
					 '',
					 year
					);
*/
    }
  },
  viewByJournal: function() {
    var sm = this.getSelectionModel();
    var journal = sm.getSelected().data.journal;
    if (journal) {
      this.setSearchQuery('journal:' + '"' + journal + '"');
      /*	Paperpile.main.tabs.newPluginTab('DB',
					 {plugin_mode:'FULLTEXT',
					 plugin_query:'journal:'+'"'+journal+'"'},
					 journal,
					 '',
					 journal
					);
*/
    }
  },

  openPDF: function() {
    var sm = this.getSelectionModel();
    if (sm.getSelected().data.pdf) {
      var pdf = sm.getSelected().data.pdf;
      var path = Paperpile.utils.catPath(Paperpile.main.globalSettings.paper_root, pdf);
      Paperpile.main.tabs.newPdfTab({
        file: path,
        title: pdf
      });
      Paperpile.main.inc_read_counter(sm.getSelected().data._rowid);
    }
  },

  onDblClick: function(grid, rowIndex, e) {

    var sm = this.getSelectionModel();
    if (sm.getCount() == 1) {
      if (!sm.getSelected().data._imported) {
        this.insertEntry();
        return;
      }
      this.openPDF();
    }
  },

  onClose: function(cont, comp) {
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/plugins/delete_grid'),
      params: {
        grid_id: this.id
      },
      method: 'GET'
    });
  }
});

Paperpile.GridDropZone = function(grid, config) {
  this.grid = grid;
  Paperpile.GridDropZone.superclass.constructor.call(this, grid.view.scroller.dom, config);
};

Ext.extend(Paperpile.GridDropZone, Ext.dd.DropZone, {
  getTargetFromEvent: function(e) {
    return e.getTarget(this.grid.getView().rowSelector);
  },

  onNodeEnter: function(target, dd, e, data) {},

  onNodeOver: function(target, dd, e, data) {
    return this.grid.onNodeOver(target, dd, e, data);
  },

  onNodeDrop: function(target, dd, e, data) {
    var retVal = this.grid.onNodeDrop(target, dd, e, data);
    return retVal;
  },
  containerScroll: true
});

Ext.reg('pp-plugin-grid', Paperpile.PluginGrid);