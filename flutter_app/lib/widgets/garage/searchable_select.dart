import 'package:flutter/material.dart';

class SearchableSelect<T> extends StatefulWidget {
  final String label;
  final String hint;
  final List<T> items;
  final T? selectedItem;
  final String Function(T) displayText;
  final void Function(T?) onSelected;
  final bool isLoading;
  final String? errorMessage;
  final IconData? prefixIcon;
  final bool enabled;
  
  // Nouvelles propriétés pour les sections
  final List<T> featuredItems;
  final String? featuredTitle;
  final String? allTitle;
  final bool showSections;

  const SearchableSelect({
    super.key,
    required this.label,
    required this.hint,
    required this.items,
    this.selectedItem,
    required this.displayText,
    required this.onSelected,
    this.isLoading = false,
    this.errorMessage,
    this.prefixIcon,
    this.enabled = true,
    this.featuredItems = const [],
    this.featuredTitle,
    this.allTitle,
    this.showSections = false,
  });

  @override
  State<SearchableSelect<T>> createState() => _SearchableSelectState<T>();
}

class _SearchableSelectState<T> extends State<SearchableSelect<T>> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  
  List<T> _filteredItems = [];
  List<T> _filteredFeaturedItems = [];
  List<T> _filteredRemainingItems = [];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.selectedItem != null
        ? widget.displayText(widget.selectedItem!)
        : '';
    _updateFilteredLists(_searchController.text);
    _searchController.addListener(_onSearchChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(SearchableSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Mettre à jour le texte seulement si selectedItem a changé ET n'est pas null
    // Ne pas réécraser si l'utilisateur est en train de taper
    if (widget.selectedItem != oldWidget.selectedItem) {
      if (widget.selectedItem != null) {
        final newText = widget.displayText(widget.selectedItem!);
        // Ne mettre à jour que si le texte actuel ne correspond pas à l'item sélectionné
        if (_searchController.text != newText) {
          _searchController.text = newText;
        }
      } else if (!_focusNode.hasFocus) {
        // Seulement vider si on n'est pas en train d'éditer
        _searchController.text = '';
      }
    }
    
    // Si enabled passe à false, fermer l'overlay
    if (oldWidget.enabled && !widget.enabled) {
      _removeOverlay();
    }
    
    // Mettre à jour les listes filtrées si les items ou la configuration changent
    if (widget.items != oldWidget.items || 
        widget.featuredItems != oldWidget.featuredItems ||
        widget.showSections != oldWidget.showSections) {
      _updateFilteredLists(_searchController.text);
      // Si overlay est visible, le reconstruire après le build
      if (_overlayEntry != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _overlayEntry != null) {
            _rebuildOverlay();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && widget.enabled && !widget.isLoading) {
      // Filtrer les items et afficher les suggestions dès le focus
      _filterItems(_searchController.text);
      _showOverlay();
    } else {
      // Délai pour permettre au onTap des InkWell de s'exécuter avant la fermeture
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!_focusNode.hasFocus && mounted) {
          _removeOverlay();
        }
      });
    }
  }

  void _onSearchChanged() {
    _filterItems(_searchController.text);
    if (_focusNode.hasFocus && _overlayEntry != null) {
      // Différer la reconstruction pour éviter setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _overlayEntry != null) {
          _rebuildOverlay();
        }
      });
    }
  }

  void _updateFilteredLists(String query) {
    if (widget.showSections && widget.featuredItems.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      
      if (query.isEmpty) {
        // Afficher toutes les featured items et tous les items restants
        _filteredFeaturedItems = widget.featuredItems;
        _filteredRemainingItems = widget.items
            .where((item) => !widget.featuredItems.contains(item))
            .toList();
      } else {
        // Filtrer avec priorité aux featured items
        _filteredFeaturedItems = widget.featuredItems
            .where((item) =>
                widget.displayText(item).toLowerCase().contains(lowerQuery))
            .toList();
        _filteredRemainingItems = widget.items
            .where((item) =>
                !widget.featuredItems.contains(item) &&
                widget.displayText(item).toLowerCase().contains(lowerQuery))
            .toList();
      }
      
      // Combiner pour _filteredItems (pour compatibilité)
      _filteredItems = [..._filteredFeaturedItems, ..._filteredRemainingItems];
    } else {
      // Comportement classique sans sections
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredItems = widget.items
            .where((item) =>
                widget.displayText(item).toLowerCase().contains(lowerQuery))
            .toList();
      }
    }
  }

  void _filterItems(String query) {
    setState(() {
      _updateFilteredLists(query);
    });
  }

  void _selectItem(T item) {
    debugPrint('[SearchableSelect] _selectItem appelé: ${widget.displayText(item)}');
    
    // Mettre à jour le texte du controller AVANT d'appeler onSelected
    final displayText = widget.displayText(item);
    _searchController.text = displayText;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: displayText.length),
    );
    
    // Appeler le callback immédiatement
    widget.onSelected(item);
    debugPrint('[SearchableSelect] Item sélectionné et callback appelé: $displayText');
    
    // Fermer l'overlay et perdre le focus après un court délai
    // pour permettre au callback de s'exécuter
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _removeOverlay();
        _focusNode.unfocus();
      }
    });
  }

  void _clearSelection() {
    _searchController.clear();
    widget.onSelected(null);
    _removeOverlay();
  }

  void _showOverlay() {
    // Ne pas afficher l'overlay si disabled ou loading
    if (!widget.enabled || widget.isLoading || _overlayEntry != null) {
      return;
    }

    final overlay = Overlay.of(context);
    final RenderBox? renderBox = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final fieldHeight = renderBox.size.height;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Barrière pour fermer au tap outside (en dessous)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  // Si on arrive ici, c'est qu'on a tapé en dehors du dropdown
                  // car les InkWell du dropdown absorbent les taps
                  _focusNode.unfocus();
                  _removeOverlay();
                },
              ),
            ),
            // Dropdown (par-dessus la barrière)
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, fieldHeight + 8),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surface,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: widget.showSections && widget.featuredItems.isNotEmpty
                        ? _buildSectionedList()
                        : _buildSimpleList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _rebuildOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  Widget _buildSectionedList() {
    final List<Widget> children = [];
    
    // Si on est en loading, afficher un indicateur
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Si aucune section n'a d'items filtrés
    if (_filteredFeaturedItems.isEmpty && _filteredRemainingItems.isEmpty) {
      // Afficher "Aucun résultat" seulement si l'utilisateur a tapé quelque chose
      if (_searchController.text.isNotEmpty) {
        return ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            ListTile(
              enabled: false,
              title: Text(
                'Aucun résultat',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      } else if (widget.items.isEmpty) {
        // Si la liste est vraiment vide (pas d'items du tout)
        return ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            ListTile(
              enabled: false,
              title: Text(
                'Aucune option disponible',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      }
    }
    
    // Section "Marques populaires"
    if (_filteredFeaturedItems.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            widget.featuredTitle ?? 'Populaires',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );
      
      for (final item in _filteredFeaturedItems) {
        children.add(
          InkWell(
            onTap: () {
              debugPrint('[SearchableSelect] InkWell onTap (featured): ${widget.displayText(item)}');
              _selectItem(item);
            },
            child: ListTile(
              dense: true,
              title: Text(widget.displayText(item)),
            ),
          ),
        );
      }
    }
    
    // Section "Toutes les marques"
    if (_filteredRemainingItems.isNotEmpty) {
      if (_filteredFeaturedItems.isNotEmpty) {
        // Ajouter un séparateur si les deux sections sont présentes
        children.add(const Divider(height: 1));
      }
      
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            widget.allTitle ?? 'Tous',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );
      
      for (final item in _filteredRemainingItems) {
        children.add(
          InkWell(
            onTap: () {
              debugPrint('[SearchableSelect] InkWell onTap (remaining): ${widget.displayText(item)}');
              _selectItem(item);
            },
            child: ListTile(
              dense: true,
              title: Text(widget.displayText(item)),
            ),
          ),
        );
      }
    }
    
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: children,
    );
  }

  Widget _buildSimpleList() {
    // Si on est en loading, afficher un indicateur
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Ne pas afficher "Aucun résultat" si on est en loading ou si la liste est vide mais qu'on n'a pas tapé
    if (_filteredItems.isEmpty) {
      // Afficher "Aucun résultat" seulement si l'utilisateur a tapé quelque chose
      if (_searchController.text.isNotEmpty) {
        return ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            ListTile(
              enabled: false,
              title: Text(
                'Aucun résultat',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      } else if (widget.items.isEmpty) {
        // Si la liste est vraiment vide (pas d'items du tout)
        return ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            ListTile(
              enabled: false,
              title: Text(
                'Aucune option disponible',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      }
    }
    
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        return InkWell(
          onTap: () {
            debugPrint('[SearchableSelect] InkWell onTap (simple): ${widget.displayText(item)}');
            _selectItem(item);
          },
          child: ListTile(
            dense: true,
            title: Text(widget.displayText(item)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        key: _fieldKey,
        controller: _searchController,
        focusNode: _focusNode,
        enabled: widget.enabled && !widget.isLoading,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon)
              : null,
          suffixIcon: widget.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _searchController.text.isNotEmpty && widget.enabled
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearSelection,
                    )
                  : null,
          errorText: widget.errorMessage,
        ),
        onTap: () {
          if (widget.enabled && !widget.isLoading) {
            // Filtrer les items et afficher les suggestions dès le tap
            _filterItems(_searchController.text);
            _showOverlay();
          }
        },
      ),
    );
  }
}
