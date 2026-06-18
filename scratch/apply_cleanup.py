import os

def main():
    file_path = 'lib/main.dart'
    if not os.path.exists(file_path):
        print(f"Error: {file_path} not found")
        return

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Update initialScrollOffset to avoid clamping of horizontal scroll initially
    old_offset = "initialScrollOffset: Offset(_targetScrollX ?? 0, _targetScrollY ?? 0),"
    new_offset = "initialScrollOffset: Offset(0, _targetScrollY ?? 0),"
    
    if old_offset in content:
        content = content.replace(old_offset, new_offset)
        print("Success: Updated initialScrollOffset to avoid horizontal clamping")
    else:
        print("Warning: initialScrollOffset block not found")

    # 2. Guard onPageChanged to prevent resetting _zoomLevel during reload
    old_page_changed = """                      onPageChanged: (PdfPageChangedDetails details) {
                        setState(() {
                          _currentPage = details.newPageNumber;
                          _zoomLevel = 1.0;
                        });
                      },"""
                      
    new_page_changed = """                      onPageChanged: (PdfPageChangedDetails details) {
                        if (_currentPage != details.newPageNumber) {
                          setState(() {
                            _currentPage = details.newPageNumber;
                            _zoomLevel = 1.0;
                          });
                        }
                      },"""

    if old_page_changed in content:
        content = content.replace(old_page_changed, new_page_changed)
        print("Success: Guarded onPageChanged zoom reset")
    else:
        print("Warning: onPageChanged block not found")

    # Write changes back
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Cleanup done successfully!")

if __name__ == '__main__':
    main()
