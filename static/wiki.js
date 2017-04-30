document.addEvent('domready', hashLoad);
window.addEvent('hashchange', hashLoad);

// redirect #some-section to #wiki-anchor-some-section
function hashLoad() {
    var hash = window.location.hash;
    if (hash.lastIndexOf('#', 0) === 0)
        hash = hash.substring(1);
    var anchor = 'wiki-anchor-' + hash;
    var el = $(anchor);
    if (el) window.location.hash = anchor;
}
