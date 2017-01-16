# Styling

Wikifier provides a simple solution to styling with CSS from within the wiki
language. Rules can be added to specific blocks and/or children of specific
blocks, and selectors like classes and block types can also narrow down the
matched elements.

### Rules for one block

    imagebox {
        file:   some-image.png;
        width:  500px;
        style {
            padding: 5px;
            background-color: red;
        }
    }

### Rules for a block's children

All children

    sec {
        style [*] {
            margin: 50px;
        }

        First paragraph. First paragraph. First paragraph. First paragraph.
        First paragraph. First paragraph. First paragraph. First paragraph.

        Second paragraph. Second paragraph. Second paragraph.
        Second paragraph. Second paragraph. Second paragraph.
    }


Children matching a class

    sec {
        style [.padded] {
            padding: 50px;
        }

        First paragraph. First paragraph. First paragraph. First paragraph.
        First paragraph. First paragraph. First paragraph. First paragraph.

        p.padded {
            Second paragraph. Second paragraph. Second paragraph.
            Second paragraph. Second paragraph. Second paragraph.
        }
    }

All children plus the parent

    sec {
        style [this, *] {
            margin: 50px;
        }

        First paragraph. First paragraph. First paragraph. First paragraph.
        First paragraph. First paragraph. First paragraph. First paragraph.

        Second paragraph. Second paragraph. Second paragraph.
        Second paragraph. Second paragraph. Second paragraph.
    }
