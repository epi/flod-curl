module flod.etc.curl;

struct CurlReader(Sink) {
	Sink sink;

	import etc.c.curl;
	import std.exception : enforce;
	import std.string : toStringz;

	const(char)* url;
	Throwable e;

	this(string url)
	{
		this.url = url.toStringz();
	}

	void open(string url)
	{
		this.url = url.toStringz();
		sink.open();
	}

	private extern(C)
	static size_t mywrite(const(void)* buf, size_t ms, size_t nm, void* obj)
	{
		CurlReader* self = cast(CurlReader*) obj;
		size_t written;
		try {
			stderr.writefln("mywrite %s %s", ms, nm);
			written = self.sink.push((cast(const(ubyte)*) buf)[0 .. ms * nm]);
		} catch (Throwable e) {
			self.e = e;
		}
		return written;
	}

	void run()
	{
		CURL* curl = enforce(curl_easy_init(), "failed to init curl");
		curl_easy_setopt(curl, CurlOption.url, url);
		curl_easy_setopt(curl, CurlOption.writefunction, &mywrite);
		curl_easy_setopt(curl, CurlOption.file, &this);
		stderr.writefln("calling curl_easy_perform");
		auto err = curl_easy_perform(curl);
		if (err != CurlError.ok)
			stderr.writefln("curlerror: %s", err);
		curl_easy_cleanup(curl);
		if (e)
			throw e;
	}
}