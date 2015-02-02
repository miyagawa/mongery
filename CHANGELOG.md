## 1.0.5 (2015/02/02)
- Added #count (gfx)

## 1.0.4 (2015/01/19)
- Support custom operators

## 1.0.3 (2015/01/09)
- Support index method to create expression indexes

## 1.0.2 (2015/01/09)
- Support mapped_properties to map system columns on Postgres
- Look up all values using string keys rather than symbol. Make sure you use indifferent_access, or stringify_key before passing the value hash to Mongery

## 1.0.1 (2014/12/22)
- Force string comparison on non-typed property

## 1.0.0 (2014/12/9)
- This is a MAJOR update and is incompatible to the previous version
- All JSON fields are now represented with JSON path (`data#>>{path}`)
- $in query is now translated to SQL IN
- More accurate comparison with nil or numeric values
- operators such as $lt, $gt can be used at the same time to chain them with AND
- Supports partial JSON value match when you don't use $- operators
- Supports casting JSON value based on JSON Schema rather than based on the bound values.

## 0.0.5 (2014/11/10)
- Use JSON path expression for nested data to avoid errors like "cannot extract element from a scalar"

## 0.0.4 (2014/10/23)
- Support insert(), update() and delete() for more compatibilities

## 0.0.3 (2014/10/22)
- Fix a quotation bug

