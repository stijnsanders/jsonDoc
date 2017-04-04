# jsonDoc
## History
_jsonDoc_ started out as _bsonDoc.pas_ and `IBSONDocument` in the [TMongoWire](https://github.com/stijnsanders/TMongoWire) project. Since it was a solid [JSON](http://json.org/) parser, based on IUnknowns (for the reference counting) and Variants (I really, really hate long lists of overloads for allkinds of types). The need arose to manipulate JSON in several projects unrelated to [MongoDB](https://mongod.org/), so the idea surfaced to have a dedicated project around `IJSONDocument`.

(To complete the move, [TMongoWire](https://github.com/stijnsanders/TMongoWire) has since then replaced `bsonDoc.pas` with `jsonDoc.pas` and separate conversion functions to convert from and to [BSON](http://bsonspec.org/).)

## API

### JSON

To create a new `IJSONDocument` instance:

    function JSON: IJSONDocument; overload;

To create and populate a new `IJSONDocument` instance:

    function JSON(const x: array of Variant): IJSONDocument; overload;

Pass a list of alternately keys and values, suffix the key with `{` to start an embedded document, and use key `}` to close it. E.g.: with

    d:=JSON(['a',1,'b{','x','foo','}','c{','x','bar','}','d',VarArrayOf([JSON(['x','hello']),JSON(['y','world'])]),'e',true]);

`d.ToString` will return `{"a":1,"b":{"x":"foo"},"c":{"x":"bar"},"d":[{"x":"hello"},{"x":"world"}],"e":true}`.

Convert a variant into an IJSONDocument reference.

    function JSON(x: Variant): IJSONDocument; overload;

Depending on the value of the argument:

* string types are parsed into a new `IJSONDocument` instance,
* Null (or empty or unassigned) returns `nil`,
* in all other cases the variant is probed for a reference to an `IJSONDocument` instace.

### IJSONDocument

Merge a string with JSON data into the `IJSONDocument` instance, existing keys will get their values overwritten (see `Clear` below).

    function Parse(const JSONData: WideString): IJSONDocument;

Convert the data in the `IJSONDocument` instance into a JSON string.

    function ToString: WideString;

Convert the data in the `IJSONDocument` instance into a Variant array of dimensions [0.._n_,0..1], where [_i_,0] holds keys and [_i_,1] holds values.

    function ToVarArray: Variant;

Clear the values of the `IJSONDocument`, but keep the list of keys.

    procedure Clear;

When processing a sequence of JSON documents with a similar set of keys (and keys of embedded documents), performance can be gained by avoiding the de- and re-allocation of memory to store the keys (and the Variant record for their values). (See also `IJSONDocArrayBuilder` below).

Retrieve a value by key. This is the default property, so you can access the keys of a `IJSONDocument` by index notation (e.g.: `d['id']`).

    property Item[const Key: WideString]: Variant; default;

## Remarks

**Attention:** by default the `IJSONDocument` implementation: `TJSONDocument` is **not** thread-safe. Please use proper locking and synchronisation methods to ensure only one thread accesses an instance at one time, or declare conditional define `JSONDOC_THREADSAFE`.

### JSONEnum

Create an `IJSONEnumerator` instance for a `IJSONDocument` reference.

    function JSONEnum(x: IJSONDocument): IJSONEnumerator; overload;
    function JSONEnum(const x: Variant): IJSONEnumerator; overload;

### IJSONEnumerator

Check wether the enumerator is past the end of the set of keys of the document.

    function EOF: boolean;

Move the iterator to the next item in the set. Moves the iterator to the first item on the first call. Returns false when moved past the end of the set.

    function Next: boolean;

Returns the key or value of the current item in the set.

    function Key: WideString;
    function Value: Variant;

Returns the key or value of the current item in the set.

### JSONDocArray

Use an `IJSONDocArrayBuilder` instance to store a set of similar JSON documents. JSON is converted to and from strings internally to save on memory usage. Use `LoadItem` with a single `IJSONDocument` instance to re-use keys and save on memory allocation. Pre-load a parent `IJSONDocument` with an `IJSONDocArrayBuilder` instance to postpone some of the parsing of the children documents.

    function JSONDocArray: IJSONDocArrayBuilder; overload;
    function JSONDocArray(const Items:array of IJSONDocument): IJSONDocArrayBuilder; overload;

### IJSONDocArrayBuilder

Append a document to the array.

    function Add(Doc: IJSONDocument): integer;
    function AddJSON(const Data: WideString): integer;

Retrieve a document using an existing `IJSONDocument` instance, possibly re-using allocated keys.

    procedure LoadItem(Index: integer; Doc: IJSONDocument);

Retrieve the number of documents in the array.

    function Count: integer; stdcall;

Convert the data in the `IJSONDocArrayBuilder` instance into a JSON string.

    function ToString: WideString; stdcall;

Retrieve a document by index, in a new `IJSONDocument` instance. This is the default property, so you can use index notation (e.g.: `a[3]`).

    property Item[Idx: integer]: IJSONDocument; default;

### IJSONArray

If you need to process documents that contain many and/or large arrays, some performance may get lost because manipulating Variant arrays performs a deep copy on assignment by default.

To prevent this, set the `JSON_UseIJSONArray` value to true to have `IJSONDocument` use `IJSONArray` instances to hold arrays, which use reference counting instead of deep copy on assignment.

A downside to this is that plain array-indexing (`a[i]`) no longer works. (The `VariantManager` which could provide support for this, is deprecated in Delphi since version 7.) Use the `ja` function to conveniently extract a `IJSONArray` reference from a variable of type Variant (`ja(a)[i]`).
