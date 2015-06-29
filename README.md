# jsonDoc
## History
_jsonDoc_ started out as _bsonDoc.pas_ and `IBSONDocument` in the [TMongoWire](https://github.com/stijnsanders/TMongoWire) project. Since it was a solid [JSON](http://json.org/) parser, based on IUnknowns (for the reference counting) and OleVariants (I really, really hate long lists of overloads for allkinds of types). I started to use _bsonDoc.pas_ and _bsonUtils.pas_ in several projects unrealted to [MongoDB](https://mongod.org/), so the idea surfaced to have a dedicated project that focusses on `IJSONDocument`.

## API

### JSON

    function JSON: IJSONDocument; overload;

Use this function to create a new `IJSONDocument` instance.

    function JSON(const x: array of OleVariant): IJSONDocument; overload;

Convert a variant array into an `IJSONDocument` instance. Pass a list of key/value-pairs, use value `[` to start an embedded document, and key `]` to close it.

    function JSON(x: OleVariant): IJSONDocument; overload;

Use this overload to convert an OleVariant into an `IJSONDocument` reference.

### IJSONDocument

    function Parse(const JSONData: WideString): IJSONDocument; safecall;

Convert a string with JSON data into the `IJSONDocument` instance.

    function ToString: WideString; safecall;

Convert the data in the `IJSONDocument` instance into a JSON string.

    function ToVarArray:OleVariant; safecall;

Convert the data in the `IJSONDocument` instance into a Variant array.

    procedure Clear; safecall;

Clear the values of the `IJSONDocument`, but keep the list of keys. When processing a sequence of JSON documents with a similar set of keys (and keys of embedded documents), performance can be gained by avoiding the de- and re-allocation of memory to store the keys (and the Variant record for their values).

    property Item[const Key: WideString]: OleVariant; default;

Get or set the value for a key. Notice this is the default property, so you can access the keys of a `IJSONDocument` by index notation (e.g.: `d['id']`)
