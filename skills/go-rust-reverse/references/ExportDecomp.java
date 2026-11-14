// Ghidra headless postScript: decompile a program's exported entry points plus
// any symbol whose name contains "panic" / "begin_unwind" (Rust anchors).
//
// Usage (Windows):
//   $env:JAVA_HOME = "<ghidra>\jdk-21..."
//   $env:KOTIK_GHIDRA_OUT = "C:\out\decomp.txt"
//   & "<ghidra>\support\analyzeHeadless.bat" <projdir> ProjName `
//       -import <binary> -scriptPath <this dir> -postScript ExportDecomp.java -deleteProject
//
// Notes:
//   - The output path comes from the KOTIK_GHIDRA_OUT environment variable.
//   - Do not add a `package` statement: Ghidra compiles postScripts standalone.
//   - getExternalEntryPointIterator() returns an AddressIterator, not a
//     SymbolIterator; a wrong type here fails only as "class could not be found",
//     so read the head of the headless log for the real javac error.
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressIterator;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import java.io.FileWriter;
import java.io.PrintWriter;

public class ExportDecomp extends GhidraScript {
    @Override
    public void run() throws Exception {
        String out = System.getenv("KOTIK_GHIDRA_OUT");
        if (out == null || out.isEmpty()) out = "ghidra-decomp.txt";
        DecompInterface ifc = new DecompInterface();
        ifc.openProgram(currentProgram);
        PrintWriter w = new PrintWriter(new FileWriter(out));
        w.println("# program=" + currentProgram.getName());
        w.println("# imageBase=" + currentProgram.getImageBase());
        w.println("# compiler=" + currentProgram.getCompiler());
        w.println("# format=" + currentProgram.getExecutableFormat());
        w.println("# language=" + currentProgram.getLanguageID());

        int exported = 0, anchors = 0;
        AddressIterator ex = currentProgram.getSymbolTable().getExternalEntryPointIterator();
        while (ex.hasNext()) {
            Address a = ex.next();
            Function f = currentProgram.getFunctionManager().getFunctionAt(a);
            if (f == null) continue;
            exported++;
            dump(w, ifc, f);
        }
        FunctionIterator fi = currentProgram.getFunctionManager().getFunctions(true);
        while (fi.hasNext()) {
            Function f = fi.next();
            String n = f.getName();
            if (n.toLowerCase().contains("panic") || n.contains("begin_unwind")) {
                anchors++;
                dump(w, ifc, f);
            }
        }
        w.println("\n# exported functions decompiled: " + exported);
        w.println("# panic/unwind anchors decompiled: " + anchors);
        w.println("# total functions in program: " + currentProgram.getFunctionManager().getFunctionCount());
        w.close();
        ifc.dispose();
    }

    private void dump(PrintWriter w, DecompInterface ifc, Function f) {
        w.println("\n===== " + f.getName() + " @ " + f.getEntryPoint() + " =====");
        try {
            DecompileResults r = ifc.decompileFunction(f, 60, monitor);
            if (r != null && r.decompileCompleted() && r.getDecompiledFunction() != null) {
                w.println(r.getDecompiledFunction().getC());
            } else {
                w.println("(decompile failed)");
            }
        } catch (Exception e) {
            w.println("(error: " + e.getMessage() + ")");
        }
    }
}
