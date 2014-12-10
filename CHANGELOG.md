## 1.0.0 (2014/12/9)
- This is a MAJOR update and is incompatible to the previous version
- All JSON fields are now represented with JSON path (`data#>>{path}`)
- $in query is now translated to SQL IN
- More accurate comparison with nil or numeric values
- operators such as $lt, $gt can be used at the same time to chain them with AND
- Supports partial JSON value match when you don't use $- operators

## 0.0.5 (2014/11/10)
- Use JSON path expression for nested data to avoid errors like "cannot extract element from a scalar"

## 0.0.4 (2014/10/23)
- Support insert(), update() and delete() for more compatibilities

## 0.0.3 (2014/10/22)
- Fix a quotation bug

